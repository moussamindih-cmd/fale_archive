-- =====================================================================
-- 20260822000500_applications.sql
-- Module « Suivi des candidatures » (cahier des charges §5.3).
--
-- État corrigé : le « Pipeline Recrutement » était une liste plate filtrée
-- sur un enum Dart figé à 5 valeurs, persisté en TEXT sans contrainte. Le
-- lien au poste se réduisait à `candidates.target_position`, un texte libre.
-- Il n'existait ni entretien, ni notation, ni notification, ni historique
-- d'étape — donc aucun moyen de calculer un délai de recrutement (§5.4.1).
--
-- Migration non destructive : `candidates` est conservée telle quelle et
-- reste la fiche du candidat ; une `application` est créée pour chaque
-- candidat existant, avec son historique amorcé.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Pipeline paramétrable (§5.3.2)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.pipeline_stages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    code            text NOT NULL,
    label           text NOT NULL,
    position        integer NOT NULL,

    -- Étape de sortie : la candidature ne bouge plus.
    is_terminal     boolean NOT NULL DEFAULT false,
    -- Étape de succès : c'est elle qui borne le délai de recrutement.
    is_won          boolean NOT NULL DEFAULT false,

    -- Durée au-delà de laquelle une candidature stagne (§5.3.6).
    sla_days        integer CHECK (sla_days IS NULL OR sla_days > 0),

    color           text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),

    UNIQUE (organization_id, code),
    UNIQUE (organization_id, position) DEFERRABLE INITIALLY DEFERRED,
    -- Une étape gagnante est nécessairement terminale.
    CONSTRAINT pipeline_won_is_terminal CHECK (NOT is_won OR is_terminal)
);

CREATE INDEX IF NOT EXISTS pipeline_stages_org
    ON public.pipeline_stages (organization_id, position);

-- Une seule étape gagnante par organisation : sans cela, le délai moyen de
-- recrutement n'aurait pas de borne unique.
CREATE UNIQUE INDEX IF NOT EXISTS pipeline_stages_single_won
    ON public.pipeline_stages (organization_id) WHERE is_won;

-- ---------------------------------------------------------------------
-- 2. Candidatures
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.applications (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),

    -- `candidates.id` est du TEXTE (`cand_<millis>`), pas un uuid.
    candidate_id    text NOT NULL REFERENCES public.candidates(id) ON DELETE CASCADE,

    -- Nullable : une candidature spontanée ne vise aucune offre, et les
    -- candidatures déjà en base n'en ont pas.
    job_offer_id    uuid REFERENCES public.job_offers(id) ON DELETE SET NULL,

    stage_id        uuid NOT NULL REFERENCES public.pipeline_stages(id),

    -- §5.4.1 : sources de candidature.
    source          text NOT NULL DEFAULT 'interne'
                    CHECK (source IN ('interne','site_web','cooptation','reseau_social',
                                      'cabinet','spontanee','salon','autre')),

    applied_at      timestamptz NOT NULL DEFAULT now(),
    -- Entrée dans l'étape courante : base du calcul de stagnation.
    stage_since     timestamptz NOT NULL DEFAULT now(),
    -- Renseigné à l'entrée dans une étape terminale : borne du délai.
    closed_at       timestamptz,

    created_at      timestamptz NOT NULL DEFAULT now(),

    -- Un même candidat ne postule qu'une fois à une offre donnée.
    --
    -- NULLS NOT DISTINCT est indispensable : par défaut PostgreSQL considère
    -- deux NULL comme différents, si bien qu'un candidat pouvait déposer
    -- autant de candidatures spontanées que voulu — et fausser d'autant les
    -- taux de conversion du §5.4.1.
    UNIQUE NULLS NOT DISTINCT (candidate_id, job_offer_id)
);

CREATE INDEX IF NOT EXISTS applications_org_stage
    ON public.applications (organization_id, stage_id);
CREATE INDEX IF NOT EXISTS applications_offer
    ON public.applications (job_offer_id, applied_at DESC);
CREATE INDEX IF NOT EXISTS applications_candidate
    ON public.applications (candidate_id);
-- Candidatures en cours, pour le tableau de bord du pipeline.
CREATE INDEX IF NOT EXISTS applications_open
    ON public.applications (organization_id, stage_since)
    WHERE closed_at IS NULL;

-- ---------------------------------------------------------------------
-- 3. Historique des étapes — source du délai de recrutement (§5.4.1)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.application_stage_history (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id uuid NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
    from_stage_id  uuid REFERENCES public.pipeline_stages(id),
    to_stage_id    uuid NOT NULL REFERENCES public.pipeline_stages(id),
    changed_by     uuid REFERENCES public.employees(id),
    changed_at     timestamptz NOT NULL DEFAULT now(),
    reason         text,
    -- Temps passé dans l'étape quittée : évite de recalculer par fenêtrage
    -- à chaque rapport.
    days_in_previous_stage integer
);

CREATE INDEX IF NOT EXISTS application_stage_history_app
    ON public.application_stage_history (application_id, changed_at);
CREATE INDEX IF NOT EXISTS application_stage_history_stage
    ON public.application_stage_history (to_stage_id, changed_at);

-- L'historique est la preuve du parcours : en ajout seul.
REVOKE UPDATE, DELETE ON public.application_stage_history FROM authenticated, anon;

-- ---------------------------------------------------------------------
-- 4. Notation et commentaires collaboratifs (§5.3.3)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.application_notes (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id uuid NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
    author_id      uuid NOT NULL REFERENCES public.employees(id),
    body           text NOT NULL CHECK (btrim(body) <> ''),
    rating         smallint CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    -- Étape à laquelle l'avis a été émis : un avis d'entretien ne pèse pas
    -- comme un avis de présélection.
    stage_id       uuid REFERENCES public.pipeline_stages(id),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS application_notes_app
    ON public.application_notes (application_id, created_at DESC);

-- ---------------------------------------------------------------------
-- 5. Entretiens (§5.3.5)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.interviews (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  uuid NOT NULL REFERENCES public.organizations(id),
    application_id   uuid NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,

    scheduled_at     timestamptz NOT NULL,
    duration_minutes integer NOT NULL DEFAULT 60 CHECK (duration_minutes > 0),
    location         text,
    meeting_url      text,
    interviewer_ids  uuid[] NOT NULL DEFAULT '{}',

    status           text NOT NULL DEFAULT 'planifie'
                     CHECK (status IN ('planifie','confirme','realise','annule','absent')),
    outcome          text,

    -- Identifiant de l'événement iCalendar : stable d'une mise à jour à
    -- l'autre, sinon chaque envoi crée un doublon dans l'agenda.
    ics_uid          text NOT NULL DEFAULT gen_random_uuid()::text,

    created_by       uuid REFERENCES public.employees(id),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS interviews_app
    ON public.interviews (application_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS interviews_upcoming
    ON public.interviews (organization_id, scheduled_at)
    WHERE status IN ('planifie','confirme');

-- ---------------------------------------------------------------------
-- 6. Gabarits de notification (§5.3.4)
-- ---------------------------------------------------------------------

-- Les messages sont éditables par les RH, pas codés en dur : chaque
-- organisation a son ton et son vocabulaire.
CREATE TABLE IF NOT EXISTS public.notification_templates (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    stage_id        uuid NOT NULL REFERENCES public.pipeline_stages(id) ON DELETE CASCADE,
    title_tpl       text NOT NULL,
    body_tpl        text NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    UNIQUE (organization_id, stage_id)
);

-- ---------------------------------------------------------------------
-- 7. Transition d'étape : historique, clôture et notification
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_application_stage_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_stage        record;
    v_days         integer;
    v_candidate    record;
    v_template     record;
    v_title        text;
    v_body         text;
BEGIN
    IF NEW.stage_id IS NOT DISTINCT FROM OLD.stage_id THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_stage FROM public.pipeline_stages WHERE id = NEW.stage_id;

    -- Une étape d'une autre organisation rattacherait la candidature à un
    -- pipeline étranger.
    IF v_stage.organization_id IS DISTINCT FROM NEW.organization_id THEN
        RAISE EXCEPTION 'Étape de pipeline étrangère à l''organisation'
            USING ERRCODE = '42501';
    END IF;

    v_days := GREATEST(0, EXTRACT(DAY FROM (now() - OLD.stage_since))::integer);

    NEW.stage_since := now();
    NEW.closed_at := CASE WHEN v_stage.is_terminal THEN now() END;

    INSERT INTO public.application_stage_history
        (application_id, from_stage_id, to_stage_id, changed_by, days_in_previous_stage)
    VALUES (NEW.id, OLD.stage_id, NEW.stage_id, auth.uid(), v_days);

    -- Notification in-app (§5.3.4). Un gabarit absent ou désactivé signifie
    -- « ne pas notifier pour cette étape » — c'est un choix, pas un oubli.
    SELECT * INTO v_template
    FROM public.notification_templates
    WHERE organization_id = NEW.organization_id
      AND stage_id = NEW.stage_id
      AND is_active;

    IF FOUND THEN
        SELECT full_name, target_position INTO v_candidate
        FROM public.candidates WHERE id = NEW.candidate_id;

        v_title := replace(replace(v_template.title_tpl,
                       '{candidat}', COALESCE(v_candidate.full_name, '')),
                       '{etape}', v_stage.label);
        v_body  := replace(replace(replace(v_template.body_tpl,
                       '{candidat}', COALESCE(v_candidate.full_name, '')),
                       '{etape}', v_stage.label),
                       '{poste}', COALESCE(v_candidate.target_position, ''));

        INSERT INTO public.in_app_notifications
            (organization_id, title, message, type, related_entity_id, target_role)
        VALUES (NEW.organization_id, v_title, v_body, 'candidateUpdate',
                NEW.candidate_id, 'rh');
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS handle_application_stage_change ON public.applications;
CREATE TRIGGER handle_application_stage_change
    BEFORE UPDATE OF stage_id ON public.applications
    FOR EACH ROW EXECUTE FUNCTION public.handle_application_stage_change();

-- Première étape : l'historique doit commencer à la création, sinon tout
-- calcul de délai démarre amputé de la première transition.
CREATE OR REPLACE FUNCTION public.seed_application_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.application_stage_history
        (application_id, from_stage_id, to_stage_id, changed_by, changed_at)
    VALUES (NEW.id, NULL, NEW.stage_id, auth.uid(), NEW.applied_at);
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS seed_application_history ON public.applications;
CREATE TRIGGER seed_application_history
    AFTER INSERT ON public.applications
    FOR EACH ROW EXECUTE FUNCTION public.seed_application_history();

-- ---------------------------------------------------------------------
-- 8. Semis du pipeline par défaut
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.seed_organization_pipeline(p_org uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.pipeline_stages
        (organization_id, code, label, position, is_terminal, is_won, sla_days, color)
    VALUES
        (p_org, 'recue',           'Reçue',           1, false, false, 7,  '#64748B'),
        (p_org, 'preselectionnee', 'Présélectionnée', 2, false, false, 7,  '#3B82F6'),
        (p_org, 'entretien',       'Entretien',       3, false, false, 14, '#8B5CF6'),
        (p_org, 'test',            'Test',            4, false, false, 10, '#F59E0B'),
        (p_org, 'offre',           'Offre',           5, false, false, 7,  '#06B6D4'),
        (p_org, 'recrutee',        'Recrutée',        6, true,  true,  NULL, '#10B981'),
        (p_org, 'rejetee',         'Rejetée',         7, true,  false, NULL, '#EF4444')
    ON CONFLICT (organization_id, code) DO NOTHING;

    -- Gabarits par défaut. Seules les étapes réellement adressées au
    -- candidat en reçoivent un.
    INSERT INTO public.notification_templates
        (organization_id, stage_id, title_tpl, body_tpl)
    SELECT p_org, s.id, t.title, t.body
    FROM public.pipeline_stages s
    JOIN (VALUES
        ('preselectionnee', 'Candidature présélectionnée',
         'La candidature de {candidat} pour le poste de {poste} passe en présélection.'),
        ('entretien', 'Entretien à planifier',
         'La candidature de {candidat} passe en phase d''entretien.'),
        ('offre', 'Offre à formaliser',
         'Une offre est à préparer pour {candidat}.'),
        ('recrutee', 'Recrutement confirmé',
         '{candidat} est recruté(e) pour le poste de {poste}.'),
        ('rejetee', 'Candidature écartée',
         'La candidature de {candidat} a été écartée.')
    ) AS t(code, title, body) ON t.code = s.code
    WHERE s.organization_id = p_org
    ON CONFLICT (organization_id, stage_id) DO NOTHING;
END $$;

-- Organisations existantes.
DO $$
DECLARE o record;
BEGIN
    FOR o IN SELECT id FROM public.organizations LOOP
        PERFORM public.seed_organization_pipeline(o.id);
    END LOOP;
END $$;

-- Nouvelles organisations : on complète le trigger de semis du lot 2.
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

    PERFORM public.seed_organization_pipeline(NEW.id);
    RETURN NEW;
END $$;

-- ---------------------------------------------------------------------
-- 9. Reprise des candidats existants — non destructive
-- ---------------------------------------------------------------------

-- Chaque candidat déjà en base reçoit une candidature, avec son statut
-- historique traduit en étape. `candidates.status` reste en place le temps
-- d'un cycle ; `target_position` devient une trace en lecture seule.
DO $$
DECLARE
    c record;
    v_stage uuid;
    v_app   uuid;
BEGIN
    FOR c IN
        SELECT * FROM public.candidates
        WHERE NOT EXISTS (
            SELECT 1 FROM public.applications a WHERE a.candidate_id = candidates.id
        )
    LOOP
        SELECT id INTO v_stage
        FROM public.pipeline_stages
        WHERE organization_id = c.organization_id
          AND code = CASE c.status
                WHEN 'enAttente'   THEN 'recue'
                WHEN 'enEntretien' THEN 'entretien'
                WHEN 'retenu'      THEN 'recrutee'
                WHEN 'rejete'      THEN 'rejetee'
                WHEN 'archive'     THEN 'rejetee'
                ELSE 'recue'
              END;

        CONTINUE WHEN v_stage IS NULL;

        INSERT INTO public.applications
            (organization_id, candidate_id, stage_id, source, applied_at, stage_since, closed_at)
        VALUES (
            c.organization_id, c.id, v_stage, 'interne',
            c.application_date, c.application_date,
            CASE WHEN c.status IN ('retenu','rejete','archive')
                 THEN c.application_date END
        )
        RETURNING id INTO v_app;

        -- Les notes RH étaient un bloc de texte libre sans auteur ni date :
        -- reversées telles quelles, attribuées à l'administrateur de
        -- l'organisation et horodatées à la date de candidature.
        IF btrim(COALESCE(c.rh_notes, '')) <> '' THEN
            INSERT INTO public.application_notes
                (application_id, author_id, body, created_at)
            SELECT v_app, e.id,
                   '[Reprise de l''ancien bloc de notes RH]' || chr(10) || c.rh_notes,
                   c.application_date
            FROM public.employees e
            WHERE e.organization_id = c.organization_id
              AND e.role IN ('admin','superAdmin')
            ORDER BY e.created_at
            LIMIT 1;
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 10. RLS
-- ---------------------------------------------------------------------

ALTER TABLE public.pipeline_stages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_stage_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_notes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interviews              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates  ENABLE ROW LEVEL SECURITY;

-- Le pipeline est visible de tous, paramétrable par l'administration seule :
-- redéfinir les étapes change la lecture de tous les indicateurs.
DROP POLICY IF EXISTS pipeline_stages_select ON public.pipeline_stages;
CREATE POLICY pipeline_stages_select ON public.pipeline_stages FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS pipeline_stages_write ON public.pipeline_stages;
CREATE POLICY pipeline_stages_write ON public.pipeline_stages FOR ALL
    USING (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin'))
    WITH CHECK (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin'));

DROP POLICY IF EXISTS applications_select ON public.applications;
CREATE POLICY applications_select ON public.applications FOR SELECT
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin','admin','directeurAdministratif','rh'));

DROP POLICY IF EXISTS applications_insert ON public.applications;
CREATE POLICY applications_insert ON public.applications FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND public.has_role('superAdmin','admin','rh'));

DROP POLICY IF EXISTS applications_update ON public.applications;
CREATE POLICY applications_update ON public.applications FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin','admin','rh'))
    WITH CHECK (public.can_access_org(organization_id));

DROP POLICY IF EXISTS applications_delete ON public.applications;
CREATE POLICY applications_delete ON public.applications FOR DELETE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin','admin'));

DROP POLICY IF EXISTS stage_history_select ON public.application_stage_history;
CREATE POLICY stage_history_select ON public.application_stage_history FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.applications a
                   WHERE a.id = application_id
                     AND public.can_access_org(a.organization_id)));

-- Les avis sont collaboratifs : chacun lit ceux des autres, mais nul ne
-- réécrit un avis qu'il n'a pas signé.
DROP POLICY IF EXISTS notes_select ON public.application_notes;
CREATE POLICY notes_select ON public.application_notes FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.applications a
                   WHERE a.id = application_id
                     AND public.can_access_org(a.organization_id))
           AND public.has_role('superAdmin','admin','directeurAdministratif','rh'));

DROP POLICY IF EXISTS notes_insert ON public.application_notes;
CREATE POLICY notes_insert ON public.application_notes FOR INSERT
    WITH CHECK (author_id = auth.uid()
                AND EXISTS (SELECT 1 FROM public.applications a
                            WHERE a.id = application_id
                              AND public.can_access_org(a.organization_id)));

DROP POLICY IF EXISTS notes_update ON public.application_notes;
CREATE POLICY notes_update ON public.application_notes FOR UPDATE
    USING (author_id = auth.uid())
    WITH CHECK (author_id = auth.uid());

DROP POLICY IF EXISTS notes_delete ON public.application_notes;
CREATE POLICY notes_delete ON public.application_notes FOR DELETE
    USING (author_id = auth.uid() OR public.has_role('superAdmin','admin'));

DROP POLICY IF EXISTS interviews_select ON public.interviews;
CREATE POLICY interviews_select ON public.interviews FOR SELECT
    USING (public.can_access_org(organization_id)
           AND (public.has_role('superAdmin','admin','directeurAdministratif','rh')
                OR auth.uid() = ANY(interviewer_ids)));

DROP POLICY IF EXISTS interviews_write ON public.interviews;
CREATE POLICY interviews_write ON public.interviews FOR ALL
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin','admin','rh'))
    WITH CHECK (public.can_access_org(organization_id)
                AND public.has_role('superAdmin','admin','rh'));

DROP POLICY IF EXISTS notification_templates_select ON public.notification_templates;
CREATE POLICY notification_templates_select ON public.notification_templates FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS notification_templates_write ON public.notification_templates;
CREATE POLICY notification_templates_write ON public.notification_templates FOR ALL
    USING (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin','rh'))
    WITH CHECK (public.can_access_org(organization_id) AND public.has_role('superAdmin','admin','rh'));

DROP TRIGGER IF EXISTS audit_applications ON public.applications;
CREATE TRIGGER audit_applications
    AFTER INSERT OR UPDATE OR DELETE ON public.applications
    FOR EACH ROW EXECUTE FUNCTION public.record_audit_log();
