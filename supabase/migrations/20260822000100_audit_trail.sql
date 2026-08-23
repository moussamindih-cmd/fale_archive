-- =====================================================================
-- 20260822000100_audit_trail.sql
-- Piste d'audit inviolable (cahier des charges §5.5.4).
--
-- État corrigé : `action_history_entries` était écrit par le client, avec
-- un acteur en texte libre (aucun auth.uid(), aucune clé étrangère), un
-- horodatage pris sur l'horloge de l'appareil, les erreurs avalées par un
-- catch silencieux, et une politique FOR ALL qui autorisait le client à
-- faire UPDATE et DELETE sur ses propres lignes d'audit. Un utilisateur
-- pouvait donc effacer la trace de ses actions.
--
-- En parallèle, l'écran d'audit lisait `business_audit_logs`, une table que
-- rien n'écrivait et qu'aucune migration ne définissait.
--
-- Les deux sont remplacées par une table unique alimentée par trigger.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),

    -- L'acteur vient de auth.uid(), jamais d'un champ fourni par le client.
    actor_id        uuid REFERENCES public.employees(id),
    -- Libellé figé au moment du fait : si l'employé est renommé plus tard,
    -- la trace doit continuer de dire qui a agi ce jour-là.
    actor_label     text NOT NULL DEFAULT 'système',
    actor_role      text,

    action          text NOT NULL
                    CHECK (action IN ('INSERT','UPDATE','DELETE','READ',
                                      'LOGIN','LOGOUT','EXPORT','PURGE',
                                      'SECURITY_VIOLATION')),
    entity_type     text NOT NULL,
    -- TEXT et non uuid : les archives, candidats et documents logistiques
    -- portent des identifiants applicatifs (`arc_1750000000`), pas des uuid.
    -- Un cast ::uuid ferait échouer le trigger, donc l'écriture métier.
    entity_id       text,

    before          jsonb,
    after           jsonb,
    details         text,

    -- Horloge serveur. Un horodatage client est invérifiable.
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_logs_org_time
    ON public.audit_logs (organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_entity
    ON public.audit_logs (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS audit_logs_actor
    ON public.audit_logs (actor_id, created_at DESC);

-- ---------------------------------------------------------------------
-- Immuabilité
-- ---------------------------------------------------------------------

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Lecture réservée à l'encadrement, dans sa propre organisation.
DROP POLICY IF EXISTS audit_logs_select ON public.audit_logs;
CREATE POLICY audit_logs_select ON public.audit_logs FOR SELECT
    USING (public.can_access_org(organization_id) AND public.is_supervisor());

-- Aucune politique INSERT/UPDATE/DELETE : les seules écritures viennent des
-- triggers SECURITY DEFINER ci-dessous, qui ne passent pas par la RLS.
REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM authenticated, anon;

-- Ceinture et bretelles : même un GRANT accidentel ne rendrait pas les
-- lignes modifiables.
CREATE OR REPLACE FUNCTION public.audit_logs_are_append_only()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'La piste d''audit est en ajout seul (% refusé)', TG_OP
        USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS audit_logs_no_update ON public.audit_logs;
CREATE TRIGGER audit_logs_no_update
    BEFORE UPDATE OR DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.audit_logs_are_append_only();

-- ---------------------------------------------------------------------
-- Trigger générique d'audit
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_org       uuid;
    v_actor     uuid := auth.uid();
    v_label     text := 'système';
    v_role      text;
    v_entity_id text;
    v_before    jsonb;
    v_after     jsonb;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_before := to_jsonb(OLD);
        v_org    := (v_before ->> 'organization_id')::uuid;
        v_entity_id := v_before ->> 'id';
    ELSE
        v_after := to_jsonb(NEW);
        v_org   := (v_after ->> 'organization_id')::uuid;
        v_entity_id := v_after ->> 'id';
        IF TG_OP = 'UPDATE' THEN
            v_before := to_jsonb(OLD);
        END IF;
    END IF;

    -- Sans organisation identifiable, on n'invente pas de rattachement :
    -- la ligne métier passe, la trace est simplement omise.
    IF v_org IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF v_actor IS NOT NULL THEN
        SELECT full_name, role INTO v_label, v_role
        FROM public.employees WHERE id = v_actor;
        v_label := COALESCE(v_label, 'compte supprimé');
    END IF;

    -- Le mot de passe et les jetons ne doivent jamais entrer dans la trace.
    v_before := v_before - 'password_hash' - 'password';
    v_after  := v_after  - 'password_hash' - 'password';

    INSERT INTO public.audit_logs (
        organization_id, actor_id, actor_label, actor_role,
        action, entity_type, entity_id, before, after
    ) VALUES (
        v_org, v_actor, v_label, v_role,
        TG_OP, TG_TABLE_NAME, v_entity_id, v_before, v_after
    );

    RETURN COALESCE(NEW, OLD);
END $$;

-- Pose du trigger sur toutes les tables sensibles existantes. Les tables des
-- lots suivants (job_offers, applications…) seront ajoutées à cette liste.
DO $$
DECLARE
    t text;
    tables text[] := ARRAY[
        'employees', 'daily_archives', 'candidates', 'logistics_items'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF to_regclass('public.' || t) IS NOT NULL THEN
            EXECUTE format('DROP TRIGGER IF EXISTS audit_%1$s ON public.%1$I', t);
            EXECUTE format(
                'CREATE TRIGGER audit_%1$s AFTER INSERT OR UPDATE OR DELETE '
                'ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.record_audit_log()',
                t);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- Journal des consultations (§5.1.5)
-- ---------------------------------------------------------------------

-- Une lecture ne déclenche aucun trigger : le client doit la déclarer.
-- La fonction ne prend pas d'acteur en paramètre — il est déduit du JWT,
-- donc non falsifiable.
CREATE OR REPLACE FUNCTION public.log_document_access(
    p_entity_type text,
    p_entity_id   text,
    p_details     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_org   uuid := public.current_user_organization_id();
    v_actor uuid := auth.uid();
    v_label text;
    v_role  text;
BEGIN
    IF v_org IS NULL OR v_actor IS NULL THEN
        RETURN;
    END IF;

    SELECT full_name, role INTO v_label, v_role
    FROM public.employees WHERE id = v_actor;

    INSERT INTO public.audit_logs (
        organization_id, actor_id, actor_label, actor_role,
        action, entity_type, entity_id, details
    ) VALUES (
        v_org, v_actor, COALESCE(v_label, 'inconnu'), v_role,
        'READ', p_entity_type, p_entity_id, p_details
    );
END $$;

GRANT EXECUTE ON FUNCTION public.log_document_access(text, text, text) TO authenticated;

-- ---------------------------------------------------------------------
-- Reprise de l'historique existant
-- ---------------------------------------------------------------------

-- Les lignes de `action_history_entries` sont conservées telles quelles :
-- leur acteur est un nom en texte libre et leur horodatage vient du client,
-- donc elles sont reversées avec actor_id NULL et un libellé explicite.
-- Elles ne sont pas réputées fiables, mais les perdre serait pire.
DO $$
BEGIN
    IF to_regclass('public.action_history_entries') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'LOGIN' LIMIT 1) THEN
        INSERT INTO public.audit_logs (
            organization_id, actor_id, actor_label, action,
            entity_type, entity_id, details, created_at
        )
        SELECT
            h.organization_id,
            NULL,
            COALESCE(h.user_name, 'inconnu') || ' (trace client, non vérifiée)',
            CASE
                WHEN h.action IN ('CREATE','ARCHIVE_SUBMIT','REGISTER') THEN 'INSERT'
                WHEN h.action IN ('UPDATE','STATUS_CHANGE','VALIDATE','REJECT',
                                  'ROLE_CHANGE','RESTORE') THEN 'UPDATE'
                WHEN h.action IN ('DELETE','PERMANENT_DELETE') THEN 'DELETE'
                WHEN h.action = 'LOGIN' THEN 'LOGIN'
                WHEN h.action = 'LOGOUT' THEN 'LOGOUT'
                ELSE 'UPDATE'
            END,
            'action_history_entries',
            COALESCE(h.candidate_id, h.logistics_item_id),
            h.details,
            h.timestamp
        FROM public.action_history_entries h
        WHERE h.organization_id IS NOT NULL;
    END IF;
END $$;

-- `business_audit_logs` était lue par l'écran d'administration sans jamais
-- être écrite. Une vue de compatibilité évite de casser tout client encore
-- pointé dessus, le temps de la bascule.
DO $$
BEGIN
    IF to_regclass('public.business_audit_logs') IS NULL THEN
        EXECUTE $view$
            CREATE OR REPLACE VIEW public.business_audit_logs AS
            SELECT
                id,
                organization_id,
                actor_id   AS employee_id,
                action     AS action_type,
                entity_type AS table_name,
                entity_id,
                details,
                created_at
            FROM public.audit_logs
        $view$;
    END IF;
END $$;
