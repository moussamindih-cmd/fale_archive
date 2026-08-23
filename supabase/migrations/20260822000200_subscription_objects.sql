-- =====================================================================
-- 20260822000200_subscription_objects.sql
-- Objets d'abonnement appelés par le code mais définis nulle part.
--
-- `subscription-status/index.ts:20` interroge la vue `active_subscriptions`
-- et `:26` appelle la RPC `expire_overdue_subscriptions()`. Ni l'une ni
-- l'autre n'existait dans le dépôt : la fonction Edge échouait sur toute
-- base reconstruite. Côté client, `subscription.dart:207` lit la colonne
-- `is_in_grace_period`, absente de la table de base — elle ne pouvait
-- venir que de cette vue manquante.
-- =====================================================================

-- Période de grâce : nombre de jours après l'échéance pendant lesquels
-- l'accès reste ouvert, défini par le plan (`grace_period_days`).
DROP VIEW IF EXISTS public.active_subscriptions;
CREATE OR REPLACE VIEW public.active_subscriptions AS
SELECT
    s.id,
    s.organization_id,
    s.plan_id,
    s.amount,
    s.currency,
    s.operator,
    s.phone_number,
    s.transaction_reference,
    s.payment_status,
    s.expires_at,
    s.activated_at,
    s.metadata,
    s.created_at,
    p.name          AS plan_name,
    p.max_users,
    p.max_storage_mb,
    p.grace_period_days,
    -- Vrai quand l'échéance est passée mais que la période de grâce court.
    (s.expires_at IS NOT NULL
     AND s.expires_at <= now()
     AND now() < s.expires_at + make_interval(days => p.grace_period_days))
                    AS is_in_grace_period,
    GREATEST(0, EXTRACT(DAY FROM (s.expires_at - now()))::int)
                    AS days_remaining
FROM public.subscriptions s
JOIN public.subscription_plans p ON p.id = s.plan_id
WHERE s.payment_status = 'paid'
  AND (
        s.expires_at IS NULL
     OR now() < s.expires_at + make_interval(days => p.grace_period_days)
  );

-- La vue hérite de la RLS des tables sous-jacentes (`security_invoker`),
-- sinon elle contournerait le cloisonnement par organisation.
ALTER VIEW public.active_subscriptions SET (security_invoker = true);

GRANT SELECT ON public.active_subscriptions TO authenticated;

-- ---------------------------------------------------------------------
-- Expiration automatique
-- ---------------------------------------------------------------------

-- Bascule en `expired` les abonnements payés dont l'échéance ET la période
-- de grâce sont dépassées. Idempotente : rejouable sans effet de bord.
-- Chaque bascule laisse une trace dans subscription_audit_log.
DROP FUNCTION IF EXISTS public.expire_overdue_subscriptions();
CREATE OR REPLACE FUNCTION public.expire_overdue_subscriptions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_count integer;
BEGIN
    WITH overdue AS (
        SELECT s.id
        FROM public.subscriptions s
        JOIN public.subscription_plans p ON p.id = s.plan_id
        WHERE s.payment_status = 'paid'
          AND s.expires_at IS NOT NULL
          AND now() >= s.expires_at + make_interval(days => p.grace_period_days)
        FOR UPDATE OF s
    ), updated AS (
        UPDATE public.subscriptions s
        SET payment_status = 'expired'
        FROM overdue o
        WHERE s.id = o.id
        RETURNING s.id
    ), logged AS (
        INSERT INTO public.subscription_audit_log
            (subscription_id, old_status, new_status, reason)
        SELECT id, 'paid', 'expired', 'expiration_automatique' FROM updated
        RETURNING 1
    )
    SELECT count(*) INTO v_count FROM logged;

    RETURN v_count;
END $$;

-- Appelée par la fonction Edge en service_role uniquement : un client ne
-- doit pas pouvoir déclencher des écritures de facturation.
REVOKE EXECUTE ON FUNCTION public.expire_overdue_subscriptions() FROM public, anon, authenticated;
