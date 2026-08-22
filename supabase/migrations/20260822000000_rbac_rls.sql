-- =====================================================================
-- 20260822000000_rbac_rls.sql
-- Durcissement du contrôle d'accès : dimension rôle, fermeture de
-- l'escalade de privilèges, RLS sur les tables de facturation.
--
-- État corrigé : chaque table portait une politique unique
--   FOR ALL USING (organization_id = current_user_organization_id())
-- qui ne connaissait que le tenant. Tout compte `employe` pouvait donc
-- lire, modifier et SUPPRIMER n'importe quelle ligne de son organisation,
-- et se promouvoir administrateur d'un simple UPDATE.
--
-- Migration non destructive : aucune donnée n'est touchée, seules les
-- politiques et contraintes sont remplacées.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Fonctions d'identité
-- ---------------------------------------------------------------------

-- `search_path` est désormais épinglé. Une fonction SECURITY DEFINER sans
-- search_path fixe peut être détournée en plaçant une table homonyme dans
-- un schéma que l'appelant contrôle.
CREATE OR REPLACE FUNCTION public.current_user_organization_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT organization_id
    FROM public.employees
    WHERE id = auth.uid()
      AND is_active
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT role
    FROM public.employees
    WHERE id = auth.uid()
      AND is_active
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.has_role(VARIADIC roles text[])
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT public.current_user_role() = ANY(roles);
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT public.current_user_role() = 'superAdmin';
$$;

-- Cloisonnement : vrai si l'appelant peut atteindre cette organisation.
-- Le super administrateur exploite la plateforme et traverse les tenants.
CREATE OR REPLACE FUNCTION public.can_access_org(target uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT target IS NOT NULL
       AND (public.is_super_admin()
            OR target = public.current_user_organization_id());
$$;

-- Rôles autorisés à encadrer (voir tout, valider, purger).
CREATE OR REPLACE FUNCTION public.is_supervisor()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT public.has_role('superAdmin', 'admin', 'directeurAdministratif');
$$;

-- ---------------------------------------------------------------------
-- 2. Retrait des anciennes politiques « tout permis »
-- ---------------------------------------------------------------------

DO $$
DECLARE
    t text;
    tables text[] := ARRAY[
        'organizations', 'employees', 'daily_archives', 'candidates',
        'logistics_items', 'action_history_entries', 'in_app_notifications',
        'subscriptions'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF to_regclass('public.' || t) IS NOT NULL THEN
            EXECUTE format('DROP POLICY IF EXISTS "Isolation par organisation" ON public.%I', t);
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 3. employees — lecture d'équipe, écriture réservée à l'administration
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS employees_select ON public.employees;
CREATE POLICY employees_select ON public.employees FOR SELECT
    USING (public.can_access_org(organization_id));

-- Seule l'administration crée des comptes. L'inscription publique passe par
-- une Edge Function en service_role, qui n'est pas soumise à la RLS.
DROP POLICY IF EXISTS employees_insert ON public.employees;
CREATE POLICY employees_insert ON public.employees FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND public.has_role('superAdmin', 'admin'));

-- Un utilisateur modifie sa propre fiche ; un administrateur, celles de son
-- organisation. Les colonnes sensibles sont verrouillées par le trigger du
-- point 4 : la RLS ne sait pas raisonner colonne par colonne.
DROP POLICY IF EXISTS employees_update ON public.employees;
CREATE POLICY employees_update ON public.employees FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND (id = auth.uid() OR public.has_role('superAdmin', 'admin')))
    WITH CHECK (public.can_access_org(organization_id));

-- Aucune suppression : un compte se désactive (`is_active`), il ne s'efface
-- pas — sinon la piste d'audit perd son acteur.
DROP POLICY IF EXISTS employees_delete ON public.employees;

-- ---------------------------------------------------------------------
-- 4. Fermeture de l'escalade de privilèges
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.guard_employee_privileges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Le service_role (Edge Functions, migrations) n'est pas concerné.
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    -- Nul ne modifie son propre rôle, son organisation, ni son activation.
    IF auth.uid() = NEW.id AND NOT public.has_role('superAdmin') THEN
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION
                'Modification de son propre rôle interdite (% -> %)', OLD.role, NEW.role
                USING ERRCODE = '42501';
        END IF;
        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
            RAISE EXCEPTION 'Changement d''organisation interdit'
                USING ERRCODE = '42501';
        END IF;
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            RAISE EXCEPTION 'Modification de sa propre activation interdite'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Seule la plateforme nomme un super administrateur.
    IF NEW.role = 'superAdmin'
       AND OLD.role IS DISTINCT FROM 'superAdmin'
       AND NOT public.has_role('superAdmin') THEN
        RAISE EXCEPTION 'Attribution du rôle superAdmin réservée à la plateforme'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS guard_employee_privileges ON public.employees;
CREATE TRIGGER guard_employee_privileges
    BEFORE UPDATE ON public.employees
    FOR EACH ROW EXECUTE FUNCTION public.guard_employee_privileges();

-- ---------------------------------------------------------------------
-- 5. daily_archives — chacun dépose les siennes, l'encadrement purge
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS archives_select ON public.daily_archives;
CREATE POLICY archives_select ON public.daily_archives FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS archives_insert ON public.daily_archives;
CREATE POLICY archives_insert ON public.daily_archives FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND (employee_id = auth.uid() OR public.is_supervisor()));

DROP POLICY IF EXISTS archives_update ON public.daily_archives;
CREATE POLICY archives_update ON public.daily_archives FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND (employee_id = auth.uid() OR public.is_supervisor()))
    WITH CHECK (public.can_access_org(organization_id));

-- La suppression définitive relève de la purge : l'utilisateur passe par
-- `deleted_at` (corbeille), qui est un UPDATE.
DROP POLICY IF EXISTS archives_delete ON public.daily_archives;
CREATE POLICY archives_delete ON public.daily_archives FOR DELETE
    USING (public.can_access_org(organization_id) AND public.is_supervisor());

-- ---------------------------------------------------------------------
-- 6. candidates — domaine RH
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS candidates_select ON public.candidates;
CREATE POLICY candidates_select ON public.candidates FOR SELECT
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin', 'directeurAdministratif', 'rh'));

DROP POLICY IF EXISTS candidates_write ON public.candidates;
CREATE POLICY candidates_write ON public.candidates FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND public.has_role('superAdmin', 'admin', 'rh'));

DROP POLICY IF EXISTS candidates_update ON public.candidates;
CREATE POLICY candidates_update ON public.candidates FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin', 'rh'))
    WITH CHECK (public.can_access_org(organization_id));

DROP POLICY IF EXISTS candidates_delete ON public.candidates;
CREATE POLICY candidates_delete ON public.candidates FOR DELETE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin'));

-- ---------------------------------------------------------------------
-- 7. logistics_items — séparation saisie / validation
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS logistics_select ON public.logistics_items;
CREATE POLICY logistics_select ON public.logistics_items FOR SELECT
    USING (public.can_access_org(organization_id));

DROP POLICY IF EXISTS logistics_insert ON public.logistics_items;
CREATE POLICY logistics_insert ON public.logistics_items FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND (registered_by_id = auth.uid() OR public.is_supervisor()));

DROP POLICY IF EXISTS logistics_update ON public.logistics_items;
CREATE POLICY logistics_update ON public.logistics_items FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND (registered_by_id = auth.uid() OR public.is_supervisor()))
    WITH CHECK (public.can_access_org(organization_id));

DROP POLICY IF EXISTS logistics_delete ON public.logistics_items;
CREATE POLICY logistics_delete ON public.logistics_items FOR DELETE
    USING (public.can_access_org(organization_id) AND public.is_supervisor());

-- Un document ne se valide pas soi-même : le statut ne peut passer à
-- `valide` ou `rejete` que par un rôle habilité, et jamais par la personne
-- qui l'a saisi.
CREATE OR REPLACE FUNCTION public.guard_logistics_validation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status IN ('valide', 'rejete') THEN
        IF NOT public.has_role('superAdmin', 'admin', 'directeurAdministratif') THEN
            RAISE EXCEPTION 'Validation logistique non autorisée pour ce rôle'
                USING ERRCODE = '42501';
        END IF;
        IF NEW.registered_by_id = auth.uid() AND NOT public.has_role('superAdmin') THEN
            RAISE EXCEPTION 'Un document ne peut être validé par son auteur'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS guard_logistics_validation ON public.logistics_items;
CREATE TRIGGER guard_logistics_validation
    BEFORE UPDATE ON public.logistics_items
    FOR EACH ROW EXECUTE FUNCTION public.guard_logistics_validation();

-- ---------------------------------------------------------------------
-- 8. in_app_notifications — chacun ne voit que ce qui lui est destiné
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS notifications_select ON public.in_app_notifications;
CREATE POLICY notifications_select ON public.in_app_notifications FOR SELECT
    USING (public.can_access_org(organization_id)
           AND (target_user_id IS NULL
                OR target_user_id = auth.uid()
                OR target_role = public.current_user_role()
                OR public.is_supervisor()));

DROP POLICY IF EXISTS notifications_insert ON public.in_app_notifications;
CREATE POLICY notifications_insert ON public.in_app_notifications FOR INSERT
    WITH CHECK (public.can_access_org(organization_id));

-- Seul le marquage « lu » est permis, sur ses propres notifications.
DROP POLICY IF EXISTS notifications_update ON public.in_app_notifications;
CREATE POLICY notifications_update ON public.in_app_notifications FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND (target_user_id = auth.uid() OR target_user_id IS NULL))
    WITH CHECK (public.can_access_org(organization_id));

-- ---------------------------------------------------------------------
-- 9. organizations et subscriptions
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS organizations_select ON public.organizations;
CREATE POLICY organizations_select ON public.organizations FOR SELECT
    USING (public.can_access_org(id));

DROP POLICY IF EXISTS organizations_update ON public.organizations;
CREATE POLICY organizations_update ON public.organizations FOR UPDATE
    USING (public.can_access_org(id) AND public.has_role('superAdmin', 'admin'))
    WITH CHECK (public.can_access_org(id));

DROP POLICY IF EXISTS subscriptions_select ON public.subscriptions;
CREATE POLICY subscriptions_select ON public.subscriptions FOR SELECT
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin', 'directeurAdministratif'));

-- Aucune politique d'écriture : les abonnements ne sont écrits que par les
-- Edge Functions de paiement, en service_role. Un client qui pourrait écrire
-- ici s'offrirait un abonnement gratuit.

-- ---------------------------------------------------------------------
-- 10. Tables de facturation laissées sans RLS
-- ---------------------------------------------------------------------

-- subscription_plans était world-writable : n'importe quel porteur de la clé
-- publiable pouvait exécuter UPDATE subscription_plans SET amount = 1.
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS plans_select ON public.subscription_plans;
CREATE POLICY plans_select ON public.subscription_plans FOR SELECT
    TO authenticated
    USING (is_active OR public.is_super_admin());

-- Aucune politique d'écriture : la grille tarifaire appartient à la
-- plateforme et se modifie en service_role.

ALTER TABLE public.subscription_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS subscription_audit_select ON public.subscription_audit_log;
CREATE POLICY subscription_audit_select ON public.subscription_audit_log FOR SELECT
    USING (public.is_super_admin());

REVOKE INSERT, UPDATE, DELETE ON public.subscription_audit_log FROM authenticated, anon;

-- Empêche le seed de dupliquer les plans à chaque `db push`
-- (l'ON CONFLICT DO NOTHING d'origine ne matchait aucune contrainte).
CREATE UNIQUE INDEX IF NOT EXISTS subscription_plans_name_key
    ON public.subscription_plans (name);

-- ---------------------------------------------------------------------
-- 11. Contraintes de domaine sur les colonnes TEXT énumérées
-- ---------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'employees_role_check') THEN
        ALTER TABLE public.employees ADD CONSTRAINT employees_role_check
            CHECK (role IN ('superAdmin','admin','directeurAdministratif','rh','employe'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subscriptions_status_check') THEN
        ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_status_check
            CHECK (payment_status IN ('pending','paid','failed','expired','cancelled'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'logistics_status_check') THEN
        ALTER TABLE public.logistics_items ADD CONSTRAINT logistics_status_check
            CHECK (status IN ('enAttente','valide','rejete'));
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 12. Bucket avatars — les politiques disaient « their own » sans le vérifier
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar." ON storage.objects;

DROP POLICY IF EXISTS avatars_public_read ON storage.objects;
DROP POLICY IF EXISTS avatars_owner_insert ON storage.objects;
DROP POLICY IF EXISTS avatars_owner_update ON storage.objects;
DROP POLICY IF EXISTS avatars_owner_delete ON storage.objects;

CREATE POLICY avatars_public_read ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

-- `owner` est renseigné par Storage à partir de auth.uid() : c'est lui qui
-- fait la différence entre « son » avatar et celui d'un collègue.
CREATE POLICY avatars_owner_insert ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND owner = auth.uid());

CREATE POLICY avatars_owner_update ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'avatars' AND owner = auth.uid())
    WITH CHECK (bucket_id = 'avatars' AND owner = auth.uid());

CREATE POLICY avatars_owner_delete ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'avatars' AND owner = auth.uid());
