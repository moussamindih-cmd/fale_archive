-- =====================================================================
-- 20260822000600_reporting.sql
-- Module « Reporting et pilotage » (cahier des charges §5.4).
--
-- État corrigé : aucun indicateur RH n'existait. Les « rapports » étaient
-- des vidages de listes en PDF, et tout comptage se faisait en Dart sur des
-- collections intégralement chargées en mémoire — ce qui ne tient pas
-- au-delà de quelques milliers de lignes et ne permet aucun agrégat
-- historique.
--
-- Toutes les vues sont en `security_invoker` : la RLS s'applique, chacun ne
-- voit que les indicateurs de son organisation.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Délai moyen de recrutement (§5.4.1)
-- ---------------------------------------------------------------------

-- Le délai se mesure de la réception à l'entrée en étape gagnante. Les
-- candidatures rejetées sont exclues : les compter allongerait
-- artificiellement un indicateur censé décrire les recrutements aboutis.
DROP VIEW IF EXISTS public.v_hr_time_to_hire;
CREATE OR REPLACE VIEW public.v_hr_time_to_hire AS
SELECT
    a.organization_id,
    a.job_offer_id,
    o.reference       AS offer_reference,
    o.title           AS offer_title,
    date_trunc('month', a.closed_at)::date AS month,
    count(*)                                        AS hires,
    round(avg(EXTRACT(EPOCH FROM (a.closed_at - a.applied_at)) / 86400)::numeric, 1)
                                                    AS avg_days,
    min(EXTRACT(EPOCH FROM (a.closed_at - a.applied_at)) / 86400)::integer AS min_days,
    max(EXTRACT(EPOCH FROM (a.closed_at - a.applied_at)) / 86400)::integer AS max_days
FROM public.applications a
JOIN public.pipeline_stages s ON s.id = a.stage_id AND s.is_won
LEFT JOIN public.job_offers o ON o.id = a.job_offer_id
WHERE a.closed_at IS NOT NULL
GROUP BY a.organization_id, a.job_offer_id, o.reference, o.title,
         date_trunc('month', a.closed_at);

ALTER VIEW public.v_hr_time_to_hire SET (security_invoker = true);

-- ---------------------------------------------------------------------
-- 2. Entonnoir et taux de conversion (§5.4.1)
-- ---------------------------------------------------------------------

-- Compte les candidatures ayant **atteint** chaque étape, d'après
-- l'historique — et non celles qui s'y trouvent actuellement. Une
-- candidature passée par l'entretien puis rejetée doit compter dans
-- l'entretien, sinon le taux de conversion est faux.
DROP VIEW IF EXISTS public.v_hr_funnel;
CREATE OR REPLACE VIEW public.v_hr_funnel AS
WITH reached AS (
    -- DISTINCT : une candidature qui repasse par une étape ne doit être
    -- comptée qu'une fois dans l'effectif de cette étape.
    SELECT DISTINCT h.to_stage_id AS stage_id, h.application_id
    FROM public.application_stage_history h
),
counted AS (
    SELECT
        s.organization_id,
        s.id       AS stage_id,
        s.code     AS stage_code,
        s.label    AS stage_label,
        s.position,
        s.is_terminal,
        s.is_won,
        count(r.application_id) AS reached_count
    FROM public.pipeline_stages s
    LEFT JOIN reached r ON r.stage_id = s.id
    GROUP BY s.organization_id, s.id, s.code, s.label, s.position,
             s.is_terminal, s.is_won
),
chained AS (
    SELECT
        c.*,
        -- Le chaînage ne suit QUE les étapes non terminales : « Rejetée »
        -- ne succède pas à « Recrutée », elle sort du parcours. Les
        -- enchaîner produisait des taux absurdes (150 %).
        CASE WHEN NOT c.is_terminal THEN
            LAG(c.reached_count) OVER (
                PARTITION BY c.organization_id, c.is_terminal
                ORDER BY c.position)
        END AS previous_count
    FROM counted c
)
SELECT
    organization_id, stage_id, stage_code, stage_label, position,
    is_terminal, is_won, reached_count, previous_count,
    CASE
        WHEN previous_count > 0
        THEN round(reached_count::numeric / previous_count * 100, 1)
    END AS conversion_rate_pct
FROM chained;

ALTER VIEW public.v_hr_funnel SET (security_invoker = true);

-- ---------------------------------------------------------------------
-- 3. Sources de candidature (§5.4.1)
-- ---------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_hr_sources;
CREATE OR REPLACE VIEW public.v_hr_sources AS
SELECT
    a.organization_id,
    a.source,
    count(*)                                                    AS total,
    count(*) FILTER (WHERE s.is_won)                            AS hired,
    count(*) FILTER (WHERE a.closed_at IS NULL)                 AS in_progress,
    -- Taux de réussite rapporté aux seules candidatures closes : inclure
    -- celles en cours ferait mécaniquement baisser toute source récente.
    CASE
        WHEN count(*) FILTER (WHERE a.closed_at IS NOT NULL) > 0
        THEN round(
            count(*) FILTER (WHERE s.is_won)::numeric
            / count(*) FILTER (WHERE a.closed_at IS NOT NULL) * 100, 1)
    END                                                         AS success_rate_pct
FROM public.applications a
JOIN public.pipeline_stages s ON s.id = a.stage_id
GROUP BY a.organization_id, a.source;

ALTER VIEW public.v_hr_sources SET (security_invoker = true);

-- ---------------------------------------------------------------------
-- 4. Volume archivé (§5.4.2)
-- ---------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_archive_volume;
CREATE OR REPLACE VIEW public.v_archive_volume AS
SELECT
    a.organization_id,
    date_trunc('month', a.archive_date)::date AS month,
    a.category_id,
    c.label                                   AS category_label,
    count(*)                                  AS archive_count,
    sum(a.document_count)                     AS document_count,
    -- Les tailles vivent dans le JSONB des pièces : on les additionne
    -- plutôt que de maintenir un compteur qui dériverait.
    COALESCE(sum((
        SELECT sum((d ->> 'sizeBytes')::bigint)
        FROM jsonb_array_elements(a.documents) AS d
    )), 0)                                    AS total_bytes
FROM public.daily_archives a
LEFT JOIN public.categories c ON c.id = a.category_id
WHERE a.deleted_at IS NULL
GROUP BY a.organization_id, date_trunc('month', a.archive_date),
         a.category_id, c.label;

ALTER VIEW public.v_archive_volume SET (security_invoker = true);

-- ---------------------------------------------------------------------
-- 5. Taux de conformité de conservation (§5.4.2)
-- ---------------------------------------------------------------------

-- Une archive est conforme si sa règle de conservation est connue et que
-- son échéance n'est pas dépassée sans décision. Une archive échue laissée
-- en l'état est *non conforme* : c'est précisément ce que l'indicateur doit
-- faire remonter, pas ce qu'il doit masquer.
DROP VIEW IF EXISTS public.v_retention_compliance;
CREATE OR REPLACE VIEW public.v_retention_compliance AS
WITH classified AS (
    SELECT
        a.organization_id,
        a.id,
        CASE
            WHEN a.purged_at IS NOT NULL             THEN 'purgee'
            WHEN a.legal_hold                        THEN 'gel_conservatoire'
            WHEN a.document_type_id IS NULL          THEN 'sans_regle'
            WHEN a.retention_until IS NULL           THEN 'sans_echeance'
            WHEN a.retention_until < CURRENT_DATE    THEN 'echue'
            WHEN a.retention_until < CURRENT_DATE + 90 THEN 'echeance_proche'
            ELSE 'conforme'
        END AS status
    FROM public.daily_archives a
    WHERE a.deleted_at IS NULL
)
SELECT
    organization_id,
    count(*)                                                  AS total,
    count(*) FILTER (WHERE status = 'conforme')               AS compliant,
    count(*) FILTER (WHERE status = 'echeance_proche')         AS expiring_soon,
    count(*) FILTER (WHERE status = 'echue')                   AS expired,
    count(*) FILTER (WHERE status = 'sans_regle')              AS unclassified,
    count(*) FILTER (WHERE status = 'gel_conservatoire')       AS legal_hold,
    count(*) FILTER (WHERE status = 'purgee')                  AS purged,
    CASE WHEN count(*) > 0 THEN round(
        count(*) FILTER (WHERE status IN ('conforme','echeance_proche','gel_conservatoire'))::numeric
        / count(*) * 100, 1)
    END                                                        AS compliance_rate_pct
FROM classified
GROUP BY organization_id;

ALTER VIEW public.v_retention_compliance SET (security_invoker = true);

-- ---------------------------------------------------------------------
-- 6. Synthèse du pilotage
-- ---------------------------------------------------------------------

-- Une seule requête pour la bannière d'indicateurs : cinq appels séparés au
-- chargement d'un tableau de bord, c'est cinq allers-retours réseau.
DROP FUNCTION IF EXISTS public.hr_dashboard_summary();
CREATE OR REPLACE FUNCTION public.hr_dashboard_summary()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
    SELECT jsonb_build_object(
        'open_applications', (
            SELECT count(*) FROM public.applications WHERE closed_at IS NULL),
        'hires_this_year', (
            SELECT count(*) FROM public.applications a
            JOIN public.pipeline_stages s ON s.id = a.stage_id AND s.is_won
            WHERE a.closed_at >= date_trunc('year', CURRENT_DATE)),
        'avg_time_to_hire', (
            SELECT round(avg(EXTRACT(EPOCH FROM (a.closed_at - a.applied_at)) / 86400)::numeric, 1)
            FROM public.applications a
            JOIN public.pipeline_stages s ON s.id = a.stage_id AND s.is_won
            WHERE a.closed_at IS NOT NULL),
        'published_offers', (
            SELECT count(*) FROM public.job_offers
            WHERE workflow_status = 'publiee' AND lifecycle_status = 'active'
              AND NOT is_template),
        'upcoming_interviews', (
            SELECT count(*) FROM public.interviews
            WHERE status IN ('planifie','confirme') AND scheduled_at >= now()),
        'archives_this_month', (
            SELECT count(*) FROM public.daily_archives
            WHERE deleted_at IS NULL
              AND archive_date >= date_trunc('month', CURRENT_DATE)),
        'retention_compliance_pct', (
            SELECT compliance_rate_pct FROM public.v_retention_compliance LIMIT 1)
    );
$$;

GRANT EXECUTE ON FUNCTION public.hr_dashboard_summary() TO authenticated;

-- ---------------------------------------------------------------------
-- 7. Tableaux de bord personnalisables (§5.4.3)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.dashboard_layouts (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    employee_id     uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
    name            text NOT NULL DEFAULT 'Mon tableau de bord',
    -- Disposition des blocs, opaque côté base : c'est le client qui en
    -- connaît la forme, et elle évoluera plus vite qu'un schéma.
    layout          jsonb NOT NULL DEFAULT '[]'::jsonb,
    is_default      boolean NOT NULL DEFAULT false,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (employee_id, name)
);

CREATE INDEX IF NOT EXISTS dashboard_layouts_employee
    ON public.dashboard_layouts (employee_id);

ALTER TABLE public.dashboard_layouts ENABLE ROW LEVEL SECURITY;

-- Une disposition est personnelle : nul ne lit ni ne modifie celle d'un
-- collègue.
DROP POLICY IF EXISTS dashboard_layouts_own ON public.dashboard_layouts;
CREATE POLICY dashboard_layouts_own ON public.dashboard_layouts FOR ALL
    USING (employee_id = auth.uid())
    WITH CHECK (employee_id = auth.uid()
                AND public.can_access_org(organization_id));

-- ---------------------------------------------------------------------
-- 8. Droits de lecture
-- ---------------------------------------------------------------------

GRANT SELECT ON
    public.v_hr_time_to_hire,
    public.v_hr_funnel,
    public.v_hr_sources,
    public.v_archive_volume,
    public.v_retention_compliance
TO authenticated;
