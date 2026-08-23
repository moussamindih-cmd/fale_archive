-- =====================================================================
-- 20260822000300_archiving.sql
-- Module « Archivage des activités » (cahier des charges §5.1).
--
-- Comble quatre manques :
--   §5.1.2 la catégorie était DÉDUITE du poste (`employee.dart:32`), jamais
--          choisie, et il n'existait aucun mot-clé ;
--   §5.1.3 la recherche était un `contains()` côté client sur les listes
--          déjà chargées en mémoire, sans index ni pagination ;
--   §5.1.4 aucune durée de conservation, aucune purge ;
--   §5.1.6 aucun versionnement — la colonne JSONB `documents` était
--          écrasée en entier à chaque modification, détruisant les états
--          antérieurs.
--
-- Non destructif : les colonnes ajoutées sont nullables ou ont une valeur
-- par défaut, les lignes existantes restent valides.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Taxonomie (§5.1.2)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.categories (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    code            text NOT NULL,
    label           text NOT NULL,
    parent_id       uuid REFERENCES public.categories(id),
    is_active       boolean NOT NULL DEFAULT true,
    sort_order      integer NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (organization_id, code)
);

CREATE INDEX IF NOT EXISTS categories_org ON public.categories (organization_id, sort_order);

-- Types de documents : ils portent la règle de conservation légale.
CREATE TABLE IF NOT EXISTS public.document_types (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  uuid NOT NULL REFERENCES public.organizations(id),
    label            text NOT NULL,
    retention_years  integer NOT NULL DEFAULT 10 CHECK (retention_years >= 0),
    warning_days     integer NOT NULL DEFAULT 90  CHECK (warning_days >= 0),
    retention_action text NOT NULL DEFAULT 'review'
                     CHECK (retention_action IN ('destroy','archive','review')),
    -- Référence du texte fondant la durée, exigée par les rapports de
    -- conformité (§5.4.2).
    legal_basis      text,
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (organization_id, label)
);

CREATE INDEX IF NOT EXISTS document_types_org ON public.document_types (organization_id);

-- ---------------------------------------------------------------------
-- 2. Enrichissement de daily_archives
-- ---------------------------------------------------------------------

ALTER TABLE public.daily_archives
    ADD COLUMN IF NOT EXISTS category_id      uuid REFERENCES public.categories(id),
    ADD COLUMN IF NOT EXISTS document_type_id uuid REFERENCES public.document_types(id),
    ADD COLUMN IF NOT EXISTS keywords         text[] NOT NULL DEFAULT '{}',
    -- Gel conservatoire : suspend toute purge, quelle que soit l'échéance
    -- (litige en cours, contrôle fiscal).
    ADD COLUMN IF NOT EXISTS legal_hold       boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS retention_until  date,
    ADD COLUMN IF NOT EXISTS purged_at        timestamptz,
    ADD COLUMN IF NOT EXISTS updated_at       timestamptz NOT NULL DEFAULT now();

-- ---------------------------------------------------------------------
-- 3. Recherche plein texte française (§5.1.3)
-- ---------------------------------------------------------------------

-- `array_to_string` est marquée STABLE par PostgreSQL (elle passe par les
-- fonctions de sortie des éléments, stables pour certains types), ce qui
-- interdit son usage dans une colonne générée. Pour du `text[]` la
-- conversion est en réalité immuable : on l'enveloppe explicitement.
CREATE OR REPLACE FUNCTION public.text_array_to_string(arr text[], sep text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
RETURNS NULL ON NULL INPUT
AS $$ SELECT array_to_string(arr, sep); $$;

-- Colonne générée : toujours cohérente avec la ligne, aucune synchronisation
-- applicative à maintenir. La forme à deux arguments de to_tsvector est
-- IMMUTABLE (la configuration est figée), ce qu'exige une colonne STORED.
ALTER TABLE public.daily_archives
    ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('french'::regconfig, coalesce(title, '')), 'A') ||
        setweight(to_tsvector('french'::regconfig, coalesce(public.text_array_to_string(keywords, ' '), '')), 'B') ||
        setweight(to_tsvector('french'::regconfig, coalesce(summary, '')), 'C') ||
        setweight(to_tsvector('french'::regconfig, coalesce(employee_name, '') || ' ' ||
                                        coalesce(category, '')), 'D')
    ) STORED;

-- Le titre pèse plus que le résumé, qui pèse plus que le nom du déposant :
-- une recherche « facture » doit remonter les archives intitulées ainsi
-- avant celles qui le mentionnent en passant.
CREATE INDEX IF NOT EXISTS daily_archives_fts
    ON public.daily_archives USING GIN (search_vector);

CREATE INDEX IF NOT EXISTS daily_archives_keywords
    ON public.daily_archives USING GIN (keywords);

CREATE INDEX IF NOT EXISTS daily_archives_category
    ON public.daily_archives (organization_id, category_id, archive_date DESC);

-- ---------------------------------------------------------------------
-- 4. Versionnement des pièces (§5.1.6)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.document_versions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    archive_id      uuid NOT NULL REFERENCES public.daily_archives(id) ON DELETE CASCADE,
    version_number  integer NOT NULL CHECK (version_number > 0),
    file_name       text NOT NULL,
    mime_type       text,
    size_bytes      bigint NOT NULL DEFAULT 0,
    checksum_sha256 text,
    -- Chemin immuable : une version ne réécrit jamais le fichier d'une
    -- version antérieure, sinon l'historique ne prouve plus rien.
    storage_path    text NOT NULL,
    comment         text,
    created_by      uuid REFERENCES public.employees(id),
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (archive_id, version_number)
);

CREATE INDEX IF NOT EXISTS document_versions_archive
    ON public.document_versions (archive_id, version_number DESC);

-- Attribue le numéro de version suivant et interdit le doublon de contenu.
CREATE OR REPLACE FUNCTION public.assign_document_version()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_last_checksum text;
BEGIN
    IF NEW.version_number IS NULL OR NEW.version_number = 0 THEN
        SELECT COALESCE(MAX(version_number), 0) + 1 INTO NEW.version_number
        FROM public.document_versions WHERE archive_id = NEW.archive_id;
    END IF;

    -- Réenregistrer un contenu identique gonfle l'historique sans rien
    -- prouver de plus.
    IF NEW.checksum_sha256 IS NOT NULL THEN
        SELECT checksum_sha256 INTO v_last_checksum
        FROM public.document_versions
        WHERE archive_id = NEW.archive_id AND file_name = NEW.file_name
        ORDER BY version_number DESC LIMIT 1;

        IF v_last_checksum = NEW.checksum_sha256 THEN
            RAISE EXCEPTION 'Version identique à la précédente pour « % »', NEW.file_name
                USING ERRCODE = '23505';
        END IF;
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS assign_document_version ON public.document_versions;
CREATE TRIGGER assign_document_version
    BEFORE INSERT ON public.document_versions
    FOR EACH ROW EXECUTE FUNCTION public.assign_document_version();

-- ---------------------------------------------------------------------
-- 5. Conservation légale (§5.1.4)
-- ---------------------------------------------------------------------

-- Calcule l'échéance en années CALENDAIRES. Une durée exprimée en
-- `n * 365` jours dérive d'environ deux jours et demi sur dix ans à cause
-- des années bissextiles — assez pour détruire une pièce avant son terme.
CREATE OR REPLACE FUNCTION public.compute_retention_until()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_years integer;
BEGIN
    NEW.updated_at := now();

    IF NEW.document_type_id IS NULL THEN
        NEW.retention_until := NULL;
        RETURN NEW;
    END IF;

    SELECT retention_years INTO v_years
    FROM public.document_types WHERE id = NEW.document_type_id;

    IF v_years IS NOT NULL THEN
        NEW.retention_until := NEW.archive_date + make_interval(years => v_years);
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS compute_retention_until ON public.daily_archives;
CREATE TRIGGER compute_retention_until
    BEFORE INSERT OR UPDATE OF archive_date, document_type_id
    ON public.daily_archives
    FOR EACH ROW EXECUTE FUNCTION public.compute_retention_until();

-- Purge des archives échues. Ne détruit QUE ce dont le type de document
-- prescrit explicitement la destruction, jamais ce qui est sous gel
-- conservatoire. Chaque destruction laisse une trace d'audit.
DROP FUNCTION IF EXISTS public.apply_retention(boolean);
CREATE OR REPLACE FUNCTION public.apply_retention(p_dry_run boolean DEFAULT true)
RETURNS TABLE (archive_id uuid, organization_id uuid, title text, retention_until date)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    CREATE TEMP TABLE _purgeable ON COMMIT DROP AS
    SELECT a.id, a.organization_id, a.title, a.retention_until
    FROM public.daily_archives a
    JOIN public.document_types dt ON dt.id = a.document_type_id
    WHERE dt.retention_action = 'destroy'
      AND a.legal_hold = false
      AND a.purged_at IS NULL
      AND a.retention_until IS NOT NULL
      AND a.retention_until <= CURRENT_DATE;

    IF NOT p_dry_run THEN
        INSERT INTO public.audit_logs (
            organization_id, actor_label, action, entity_type, entity_id, details
        )
        SELECT p.organization_id, 'purge automatique', 'PURGE', 'daily_archives',
               p.id,
               format('Destruction au terme de la conservation légale (échéance %s)',
                      p.retention_until)
        FROM _purgeable p;

        UPDATE public.daily_archives a
        SET purged_at = now(),
            documents = '[]'::jsonb,
            summary   = '[Contenu détruit au terme de la durée légale de conservation]'
        FROM _purgeable p
        WHERE a.id = p.id;
    END IF;

    RETURN QUERY SELECT * FROM _purgeable;
END $$;

REVOKE EXECUTE ON FUNCTION public.apply_retention(boolean) FROM public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Recherche serveur (§5.1.3)
-- ---------------------------------------------------------------------

-- Remplace le filtrage client. Le classement combine la pertinence
-- textuelle et la fraîcheur : à pertinence égale, l'archive la plus
-- récente remonte.
DROP FUNCTION IF EXISTS public.search_archives(text, uuid, date, date, uuid, integer, integer);
CREATE OR REPLACE FUNCTION public.search_archives(
    p_query      text DEFAULT NULL,
    p_category   uuid DEFAULT NULL,
    p_from       date DEFAULT NULL,
    p_to         date DEFAULT NULL,
    p_employee   uuid DEFAULT NULL,
    p_limit      integer DEFAULT 50,
    p_offset     integer DEFAULT 0
)
RETURNS TABLE (
    id uuid, title text, summary text, category text,
    employee_name text, archive_date date, document_count integer,
    keywords text[], rank real, total_count bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER          -- la RLS s'applique : chacun ne voit que son org
SET search_path = public, pg_temp
AS $$
    WITH q AS (
        SELECT CASE
                 WHEN p_query IS NULL OR btrim(p_query) = '' THEN NULL
                 ELSE websearch_to_tsquery('french'::regconfig, p_query)
               END AS ts
    ),
    filtered AS (
        SELECT a.*,
               CASE WHEN (SELECT ts FROM q) IS NULL THEN 0
                    ELSE ts_rank(a.search_vector, (SELECT ts FROM q))
               END AS rank
        FROM public.daily_archives a
        WHERE a.deleted_at IS NULL
          AND a.purged_at IS NULL
          AND ((SELECT ts FROM q) IS NULL OR a.search_vector @@ (SELECT ts FROM q))
          AND (p_category IS NULL OR a.category_id = p_category)
          AND (p_from     IS NULL OR a.archive_date >= p_from)
          AND (p_to       IS NULL OR a.archive_date <= p_to)
          AND (p_employee IS NULL OR a.employee_id = p_employee)
    )
    SELECT f.id, f.title, f.summary, f.category, f.employee_name,
           f.archive_date, f.document_count, f.keywords, f.rank::real,
           count(*) OVER () AS total_count
    FROM filtered f
    ORDER BY f.rank DESC, f.archive_date DESC
    LIMIT  GREATEST(1, LEAST(p_limit, 200))
    OFFSET GREATEST(0, p_offset);
$$;

GRANT EXECUTE ON FUNCTION public.search_archives(text, uuid, date, date, uuid, integer, integer)
    TO authenticated;

-- ---------------------------------------------------------------------
-- 7. RLS des nouvelles tables
-- ---------------------------------------------------------------------

ALTER TABLE public.categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_types    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS categories_select ON public.categories;
CREATE POLICY categories_select ON public.categories FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS categories_write ON public.categories;
CREATE POLICY categories_write ON public.categories FOR ALL
    USING (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin'))
    WITH CHECK (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin'));

DROP POLICY IF EXISTS document_types_select ON public.document_types;
CREATE POLICY document_types_select ON public.document_types FOR SELECT
    USING (public.can_access_org(organization_id));

-- Les durées légales engagent l'entreprise : seule l'administration y touche.
DROP POLICY IF EXISTS document_types_write ON public.document_types;
CREATE POLICY document_types_write ON public.document_types FOR ALL
    USING (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin'))
    WITH CHECK (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin'));

DROP POLICY IF EXISTS document_versions_select ON public.document_versions;
CREATE POLICY document_versions_select ON public.document_versions FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS document_versions_insert ON public.document_versions;
CREATE POLICY document_versions_insert ON public.document_versions FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND EXISTS (SELECT 1 FROM public.daily_archives a
                            WHERE a.id = archive_id
                              AND (a.employee_id = auth.uid() OR public.is_supervisor())));

-- Aucune politique UPDATE/DELETE : l'historique des versions est en ajout
-- seul, sinon il ne vaut rien comme preuve.
REVOKE UPDATE, DELETE ON public.document_versions FROM authenticated, anon;

-- Audit des nouvelles tables sensibles.
DROP TRIGGER IF EXISTS audit_document_types ON public.document_types;
CREATE TRIGGER audit_document_types
    AFTER INSERT OR UPDATE OR DELETE ON public.document_types
    FOR EACH ROW EXECUTE FUNCTION public.record_audit_log();

-- ---------------------------------------------------------------------
-- 8. Taxonomie par défaut
-- ---------------------------------------------------------------------

-- Reprend les cinq catégories jusqu'ici codées en dur dans
-- `employee.dart:32`, où elles étaient déduites du poste.
INSERT INTO public.categories (organization_id, code, label, sort_order)
SELECT o.id, c.code, c.label, c.sort_order
FROM public.organizations o
CROSS JOIN (VALUES
    ('courriers',  'Courriers & Correspondances du jour', 1),
    ('comptable',  'Pièces Comptables & Journal de Caisse', 2),
    ('operations', 'Dossiers Opérationnels & Rapports', 3),
    ('expertises', 'Avis Techniques & Expertises', 4),
    ('syntheses',  'Synthèses & Notes de Projets', 5),
    ('divers',     'Documents du jour', 6)
) AS c(code, label, sort_order)
ON CONFLICT (organization_id, code) DO NOTHING;

INSERT INTO public.document_types
    (organization_id, label, retention_years, retention_action, legal_basis)
SELECT o.id, t.label, t.years, t.action, t.basis
FROM public.organizations o
CROSS JOIN (VALUES
    ('Pièce comptable',      10, 'destroy', 'Acte uniforme OHADA, art. 24'),
    ('Contrat',              30, 'archive', 'Prescription trentenaire'),
    ('Dossier du personnel',  5, 'review',  'Code du travail'),
    ('Correspondance',        5, 'destroy', NULL),
    ('Document non classé',  10, 'review',  NULL)
) AS t(label, years, action, basis)
ON CONFLICT (organization_id, label) DO NOTHING;
