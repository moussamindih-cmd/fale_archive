-- =====================================================================
-- 20260822000400_job_offers.sql
-- Module « Offres d'emploi » (cahier des charges §5.2).
--
-- Module entièrement absent : ni table, ni modèle, ni écran. Le lien entre
-- un candidat et un poste se réduisait à `candidates.target_position`, un
-- texte libre choisi parmi cinq intitulés codés en dur côté client.
--
-- La page publique (§5.2.4) est reportée, mais le schéma est conçu pour
-- l'accueillir sans migration corrective : la vue `public_job_offers`
-- existe dès maintenant et n'expose que ce qu'un candidat externe doit
-- voir. Le lot différé n'aura qu'à lui accorder le rôle `anon`.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Table des offres
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.job_offers (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  uuid NOT NULL REFERENCES public.organizations(id),

    -- Référence lisible, attribuée par trigger : OFF-2026-001, par
    -- organisation et par année.
    reference        text NOT NULL,

    title            text NOT NULL CHECK (btrim(title) <> ''),
    description      text NOT NULL DEFAULT '',
    requirements     text,
    skills           text[] NOT NULL DEFAULT '{}',

    contract_type    text NOT NULL DEFAULT 'cdi'
                     CHECK (contract_type IN ('cdi','cdd','stage','interim','consultance')),
    location         text,
    positions_count  integer NOT NULL DEFAULT 1 CHECK (positions_count > 0),

    salary_min       numeric CHECK (salary_min IS NULL OR salary_min >= 0),
    salary_max       numeric,
    salary_currency  text NOT NULL DEFAULT 'XAF',
    -- Le salaire peut être renseigné en interne sans être publié.
    salary_visible   boolean NOT NULL DEFAULT false,

    deadline         date,

    -- Deux axes volontairement distincts (§5.2.2 et §5.2.3) : le workflow
    -- de validation décrit COMMENT l'offre a été approuvée, le cycle de vie
    -- décrit OÙ elle en est une fois publiée. Une offre publiée puis
    -- suspendue n'est pas revenue au brouillon ; les fusionner obligerait à
    -- une migration au premier cas réel.
    workflow_status  text NOT NULL DEFAULT 'brouillon'
                     CHECK (workflow_status IN ('brouillon','en_validation','publiee','rejetee')),
    lifecycle_status text NOT NULL DEFAULT 'active'
                     CHECK (lifecycle_status IN ('active','suspendue','pourvue','archivee')),

    -- Un modèle réutilisable (§5.2.5) est une offre comme une autre, mais
    -- jamais publiable : la vue publique l'exclut par construction.
    is_template      boolean NOT NULL DEFAULT false,
    template_name    text,

    published_at     timestamptz,
    rejection_reason text,

    created_by       uuid REFERENCES public.employees(id),
    validated_by     uuid REFERENCES public.employees(id),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),

    UNIQUE (organization_id, reference),

    -- Une fourchette inversée est une erreur de saisie, pas une donnée.
    CONSTRAINT job_offers_salary_range
        CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_max >= salary_min),
    -- Un modèle n'a pas de cycle de publication.
    CONSTRAINT job_offers_template_not_published
        CHECK (NOT is_template OR workflow_status = 'brouillon')
);

CREATE INDEX IF NOT EXISTS job_offers_org
    ON public.job_offers (organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS job_offers_published
    ON public.job_offers (organization_id, published_at DESC)
    WHERE workflow_status = 'publiee' AND lifecycle_status = 'active';
CREATE INDEX IF NOT EXISTS job_offers_templates
    ON public.job_offers (organization_id) WHERE is_template;
CREATE INDEX IF NOT EXISTS job_offers_skills
    ON public.job_offers USING GIN (skills);
CREATE INDEX IF NOT EXISTS job_offers_fts
    ON public.job_offers USING GIN (
        to_tsvector('french'::regconfig,
            coalesce(title,'') || ' ' || coalesce(description,'') || ' ' ||
            coalesce(public.text_array_to_string(skills,' '),''))
    );

-- ---------------------------------------------------------------------
-- 2. Référence automatique
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.assign_job_offer_reference()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_year text := to_char(now(), 'YYYY');
    v_next integer;
BEGIN
    IF NEW.reference IS NOT NULL AND btrim(NEW.reference) <> '' THEN
        RETURN NEW;
    END IF;

    -- Compteur par organisation et par année. Le UNIQUE sur
    -- (organization_id, reference) rattrape une éventuelle collision entre
    -- deux insertions concurrentes.
    SELECT COALESCE(MAX(substring(reference from '[0-9]+$')::integer), 0) + 1
    INTO v_next
    FROM public.job_offers
    WHERE organization_id = NEW.organization_id
      AND reference LIKE 'OFF-' || v_year || '-%';

    NEW.reference := 'OFF-' || v_year || '-' || lpad(v_next::text, 3, '0');
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS assign_job_offer_reference ON public.job_offers;
CREATE TRIGGER assign_job_offer_reference
    BEFORE INSERT ON public.job_offers
    FOR EACH ROW EXECUTE FUNCTION public.assign_job_offer_reference();

-- ---------------------------------------------------------------------
-- 3. Workflow de validation (§5.2.2)
-- ---------------------------------------------------------------------

-- Journal des transitions : qui a soumis, qui a validé, qui a rejeté et
-- pourquoi. Sans cette trace, « publiée » ne dit pas par qui.
CREATE TABLE IF NOT EXISTS public.job_offer_transitions (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_offer_id uuid NOT NULL REFERENCES public.job_offers(id) ON DELETE CASCADE,
    from_status  text,
    to_status    text NOT NULL,
    changed_by   uuid REFERENCES public.employees(id),
    changed_at   timestamptz NOT NULL DEFAULT now(),
    reason       text
);

CREATE INDEX IF NOT EXISTS job_offer_transitions_offer
    ON public.job_offer_transitions (job_offer_id, changed_at DESC);

-- Transitions autorisées. Les interdire côté base et non seulement dans
-- l'interface est ce qui empêche de publier une offre sans validation par
-- un simple appel PostgREST.
CREATE OR REPLACE FUNCTION public.guard_job_offer_workflow()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_allowed boolean;
BEGIN
    NEW.updated_at := now();

    IF NEW.workflow_status IS NOT DISTINCT FROM OLD.workflow_status THEN
        RETURN NEW;
    END IF;

    v_allowed := CASE
        WHEN OLD.workflow_status = 'brouillon'
             AND NEW.workflow_status IN ('en_validation') THEN true
        WHEN OLD.workflow_status = 'en_validation'
             AND NEW.workflow_status IN ('publiee','rejetee','brouillon') THEN true
        -- Une offre rejetée repart en correction, elle n'est pas perdue.
        WHEN OLD.workflow_status = 'rejetee'
             AND NEW.workflow_status = 'brouillon' THEN true
        -- Une offre publiée ne redevient jamais brouillon : on la retire par
        -- le cycle de vie (suspendue / archivée), ce qui préserve l'historique.
        ELSE false
    END;

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Transition de workflow interdite : % -> %',
            OLD.workflow_status, NEW.workflow_status
            USING ERRCODE = '23514';
    END IF;

    -- Seuls les rôles habilités valident ou publient (§5.2.2).
    IF NEW.workflow_status IN ('publiee','rejetee')
       AND auth.uid() IS NOT NULL
       AND NOT public.has_role('superAdmin','admin','directeurAdministratif') THEN
        RAISE EXCEPTION 'Validation d''offre non autorisée pour ce rôle'
            USING ERRCODE = '42501';
    END IF;

    IF NEW.workflow_status = 'publiee' THEN
        NEW.published_at := COALESCE(NEW.published_at, now());
        NEW.validated_by := COALESCE(NEW.validated_by, auth.uid());
        NEW.rejection_reason := NULL;
    END IF;

    IF NEW.workflow_status = 'rejetee' AND btrim(COALESCE(NEW.rejection_reason,'')) = '' THEN
        RAISE EXCEPTION 'Un rejet doit être motivé'
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO public.job_offer_transitions
        (job_offer_id, from_status, to_status, changed_by, reason)
    VALUES (NEW.id, OLD.workflow_status, NEW.workflow_status, auth.uid(),
            NEW.rejection_reason);

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS guard_job_offer_workflow ON public.job_offers;
CREATE TRIGGER guard_job_offer_workflow
    BEFORE UPDATE ON public.job_offers
    FOR EACH ROW EXECUTE FUNCTION public.guard_job_offer_workflow();

-- ---------------------------------------------------------------------
-- 4. Duplication et modèles (§5.2.5)
-- ---------------------------------------------------------------------

-- Un seul chemin pour dupliquer une offre ou instancier un modèle : la
-- copie repart systématiquement en brouillon, sans référence ni date de
-- publication héritées.
CREATE OR REPLACE FUNCTION public.duplicate_job_offer(
    p_source_id  uuid,
    p_as_template boolean DEFAULT false,
    p_title      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER          -- la RLS s'applique : on ne copie que ce qu'on voit
SET search_path = public, pg_temp
AS $$
DECLARE
    v_new_id uuid;
BEGIN
    INSERT INTO public.job_offers (
        organization_id, title, description, requirements, skills,
        contract_type, location, positions_count,
        salary_min, salary_max, salary_currency, salary_visible,
        deadline, is_template, template_name, created_by
    )
    SELECT
        s.organization_id,
        COALESCE(p_title, s.title || ' (copie)'),
        s.description, s.requirements, s.skills,
        s.contract_type, s.location, s.positions_count,
        s.salary_min, s.salary_max, s.salary_currency, s.salary_visible,
        -- Une échéance dépassée n'a pas de sens sur une copie neuve.
        CASE WHEN s.deadline > CURRENT_DATE THEN s.deadline END,
        p_as_template,
        CASE WHEN p_as_template THEN COALESCE(p_title, s.title) END,
        auth.uid()
    FROM public.job_offers s
    WHERE s.id = p_source_id
    RETURNING id INTO v_new_id;

    IF v_new_id IS NULL THEN
        RAISE EXCEPTION 'Offre source introuvable ou inaccessible'
            USING ERRCODE = '42501';
    END IF;

    RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION public.duplicate_job_offer(uuid, boolean, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 5. Vue publique — préparée, pas encore ouverte (§5.2.4)
-- ---------------------------------------------------------------------

-- L'anonyme ne touchera jamais la table : ni les statuts internes, ni
-- l'auteur, ni le validateur, ni un salaire non publié n'y figurent. Le lot
-- différé n'aura qu'à exécuter :
--     GRANT SELECT ON public.public_job_offers TO anon;
-- et à ajouter une politique de lecture anonyme sur job_offers.
CREATE OR REPLACE VIEW public.public_job_offers AS
SELECT
    o.id,
    o.organization_id,
    o.reference,
    o.title,
    o.description,
    o.requirements,
    o.skills,
    o.contract_type,
    o.location,
    o.positions_count,
    o.deadline,
    o.published_at,
    CASE WHEN o.salary_visible THEN o.salary_min END AS salary_min,
    CASE WHEN o.salary_visible THEN o.salary_max END AS salary_max,
    CASE WHEN o.salary_visible THEN o.salary_currency END AS salary_currency
FROM public.job_offers o
WHERE o.workflow_status = 'publiee'
  AND o.lifecycle_status = 'active'
  AND NOT o.is_template
  AND (o.deadline IS NULL OR o.deadline >= CURRENT_DATE);

ALTER VIEW public.public_job_offers SET (security_invoker = true);
GRANT SELECT ON public.public_job_offers TO authenticated;

-- ---------------------------------------------------------------------
-- 6. RLS
-- ---------------------------------------------------------------------

ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_offer_transitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS job_offers_select ON public.job_offers;
CREATE POLICY job_offers_select ON public.job_offers FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS job_offers_insert ON public.job_offers;
CREATE POLICY job_offers_insert ON public.job_offers FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND public.has_role('superAdmin','admin','rh'));

DROP POLICY IF EXISTS job_offers_update ON public.job_offers;
CREATE POLICY job_offers_update ON public.job_offers FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin','admin','rh','directeurAdministratif'))
    WITH CHECK (public.can_access_org(organization_id));

-- Une offre ayant vécu ne se supprime pas : elle s'archive. Seul le
-- brouillon jamais soumis peut disparaître.
DROP POLICY IF EXISTS job_offers_delete ON public.job_offers;
CREATE POLICY job_offers_delete ON public.job_offers FOR DELETE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin','admin','rh')
           AND workflow_status = 'brouillon'
           AND published_at IS NULL);

DROP POLICY IF EXISTS job_offer_transitions_select ON public.job_offer_transitions;
CREATE POLICY job_offer_transitions_select ON public.job_offer_transitions FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.job_offers o
                   WHERE o.id = job_offer_id
                     AND public.can_access_org(o.organization_id)));

-- Le journal des transitions est écrit par le trigger, jamais par le client.
REVOKE INSERT, UPDATE, DELETE ON public.job_offer_transitions FROM authenticated, anon;

DROP TRIGGER IF EXISTS audit_job_offers ON public.job_offers;
CREATE TRIGGER audit_job_offers
    AFTER INSERT OR UPDATE OR DELETE ON public.job_offers
    FOR EACH ROW EXECUTE FUNCTION public.record_audit_log();

-- ---------------------------------------------------------------------
-- 7. Semis de la taxonomie pour toute nouvelle organisation
-- ---------------------------------------------------------------------

-- Le semis de la migration 20260822000300 ne couvrait que les organisations
-- existant au moment de son exécution : une organisation créée ensuite
-- démarrait sans plan de classement ni durée de conservation.
CREATE OR REPLACE FUNCTION public.seed_organization_taxonomy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.categories (organization_id, code, label, sort_order)
    VALUES
        (NEW.id, 'courriers',  'Courriers & Correspondances du jour', 1),
        (NEW.id, 'comptable',  'Pièces Comptables & Journal de Caisse', 2),
        (NEW.id, 'operations', 'Dossiers Opérationnels & Rapports', 3),
        (NEW.id, 'expertises', 'Avis Techniques & Expertises', 4),
        (NEW.id, 'syntheses',  'Synthèses & Notes de Projets', 5),
        (NEW.id, 'divers',     'Documents du jour', 6)
    ON CONFLICT (organization_id, code) DO NOTHING;

    INSERT INTO public.document_types
        (organization_id, label, retention_years, retention_action, legal_basis)
    VALUES
        (NEW.id, 'Pièce comptable',      10, 'destroy', 'Acte uniforme OHADA, art. 24'),
        (NEW.id, 'Contrat',              30, 'archive', 'Prescription trentenaire'),
        (NEW.id, 'Dossier du personnel',  5, 'review',  'Code du travail'),
        (NEW.id, 'Correspondance',        5, 'destroy', NULL),
        (NEW.id, 'Document non classé',  10, 'review',  NULL)
    ON CONFLICT (organization_id, label) DO NOTHING;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS seed_organization_taxonomy ON public.organizations;
CREATE TRIGGER seed_organization_taxonomy
    AFTER INSERT ON public.organizations
    FOR EACH ROW EXECUTE FUNCTION public.seed_organization_taxonomy();
