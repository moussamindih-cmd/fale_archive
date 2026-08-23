-- =====================================================================
-- 20260823000000_company_onboarding.sql
-- Inscription en deux temps : l'entreprise puis son administrateur, et
-- liste d'adresses autorisées pour les comptes employés.
--
-- État corrigé : l'inscription publique était morte. `20260822000000_rbac_rls.sql`
-- a retiré la politique d'INSERT sur `organizations` (il ne reste que
-- `organizations_select` / `organizations_update`, l.320-327) et exige
-- `has_role('superAdmin','admin')` pour `employees_insert` (l.120). Un nouvel
-- inscrit n'ayant pas encore de ligne `employees`, `current_user_role()` renvoie
-- NULL : il ne satisfaisait ni l'une ni l'autre. Le commentaire l.117 annonçait
-- « L'inscription publique passe par une Edge Function en service_role » — cette
-- migration pose les tables que cette fonction manipule.
--
-- Migration non destructive : aucune donnée n'est touchée.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. organizations — donner une identité à l'entreprise
-- ---------------------------------------------------------------------

-- L'organisation naissait sans identité : `name` valait « Organisation de
-- <prénom> » (`supabase_service.dart:60`) et rien ne reliait un domaine de
-- messagerie à un tenant. `company_email` est saisi à la première étape de
-- l'inscription ; `email_domain` en est dérivé, en minuscules.
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS company_email text;
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS email_domain  text;

-- Deux entreprises ne peuvent revendiquer le même domaine : c'est ce qui rend
-- la liste d'autorisation attribuable sans ambiguïté. Index PARTIEL — les
-- organisations créées avant cette migration n'ont pas de domaine et ne
-- doivent pas entrer en collision entre elles sur NULL.
CREATE UNIQUE INDEX IF NOT EXISTS organizations_email_domain_key
    ON public.organizations (email_domain)
    WHERE email_domain IS NOT NULL;

-- ---------------------------------------------------------------------
-- 2. allowed_employee_emails — la liste d'autorisation
-- ---------------------------------------------------------------------
--
-- L'administrateur y enregistre les adresses professionnelles de ses employés,
-- avec le rôle et le poste de chacun. À l'inscription, une adresse absente de
-- cette table ne donne aucun compte.
CREATE TABLE IF NOT EXISTS public.allowed_employee_emails (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    email           text NOT NULL,
    -- Facultatif : pré-remplit le formulaire et permet à l'admin de se relire.
    full_name       text,
    role            text NOT NULL DEFAULT 'employe',
    job_title       text NOT NULL DEFAULT '',
    status          text NOT NULL DEFAULT 'pending',
    invited_by      uuid REFERENCES public.employees(id),
    claimed_by      uuid REFERENCES public.employees(id),
    claimed_at      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),

    -- `superAdmin` est volontairement absent : la plateforme seule nomme un
    -- super administrateur, comme le fait déjà guard_employee_privileges()
    -- (20260822000000_rbac_rls.sql:171). Sans cette exclusion, un admin
    -- s'offrirait un compte traversant les tenants en pré-inscrivant une adresse.
    CONSTRAINT allowed_emails_role_check
        CHECK (role IN ('admin', 'directeurAdministratif', 'rh', 'employe')),
    CONSTRAINT allowed_emails_status_check
        CHECK (status IN ('pending', 'registered', 'revoked'))
);

-- Unicité GLOBALE, calquée sur `employees_email_key` : une adresse appartient à
-- au plus une organisation. Sans cela, deux entreprises pourraient lister la
-- même adresse et l'inscription ne saurait pas quel tenant rejoindre.
CREATE UNIQUE INDEX IF NOT EXISTS allowed_emails_email_key
    ON public.allowed_employee_emails (lower(email));

CREATE INDEX IF NOT EXISTS allowed_emails_org
    ON public.allowed_employee_emails (organization_id, status);

-- ---------------------------------------------------------------------
-- 3. RLS — la liste n'est visible que de l'administration de son tenant
-- ---------------------------------------------------------------------
--
-- Aucune politique pour `anon` : exposer cette table donnerait l'annuaire des
-- adresses de l'entreprise à qui la demande. La confrontation à l'inscription
-- se fait exclusivement en service_role, dans l'Edge Function `signup-employee`.
ALTER TABLE public.allowed_employee_emails ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS allowed_emails_select ON public.allowed_employee_emails;
CREATE POLICY allowed_emails_select ON public.allowed_employee_emails FOR SELECT
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin'));

DROP POLICY IF EXISTS allowed_emails_insert ON public.allowed_employee_emails;
CREATE POLICY allowed_emails_insert ON public.allowed_employee_emails FOR INSERT
    WITH CHECK (public.can_access_org(organization_id)
                AND public.has_role('superAdmin', 'admin'));

DROP POLICY IF EXISTS allowed_emails_update ON public.allowed_employee_emails;
CREATE POLICY allowed_emails_update ON public.allowed_employee_emails FOR UPDATE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin'))
    WITH CHECK (public.can_access_org(organization_id));

-- Une entrée déjà utilisée ne s'efface pas : elle se révoque (`status`), sinon
-- le compte créé perd la trace de son autorisation.
DROP POLICY IF EXISTS allowed_emails_delete ON public.allowed_employee_emails;
CREATE POLICY allowed_emails_delete ON public.allowed_employee_emails FOR DELETE
    USING (public.can_access_org(organization_id)
           AND public.has_role('superAdmin', 'admin')
           AND status <> 'registered');

-- ---------------------------------------------------------------------
-- 4. Garde-fou : le statut ne se réécrit pas à la main
-- ---------------------------------------------------------------------
--
-- `status = 'registered'` est posé par l'Edge Function au moment où le compte
-- est réellement créé. Un admin qui le remettrait à 'pending' rouvrirait une
-- seconde inscription sur une adresse déjà consommée.
CREATE OR REPLACE FUNCTION public.guard_allowed_email_status()
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

    IF OLD.status = 'registered' AND NEW.status <> 'registered' THEN
        RAISE EXCEPTION
            'Cette adresse a déjà servi à créer un compte : révoquez le compte, pas l''autorisation.'
            USING ERRCODE = '42501';
    END IF;

    -- L'appartenance au tenant et le rattachement au compte créé sont posés par
    -- la fonction Edge ; les réécrire depuis le client déplacerait un employé
    -- d'une organisation à l'autre.
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.claimed_by IS DISTINCT FROM OLD.claimed_by THEN
        RAISE EXCEPTION 'Rattachement d''une autorisation non modifiable'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS guard_allowed_email_status ON public.allowed_employee_emails;
CREATE TRIGGER guard_allowed_email_status
    BEFORE UPDATE ON public.allowed_employee_emails
    FOR EACH ROW EXECUTE FUNCTION public.guard_allowed_email_status();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.allowed_employee_emails TO authenticated;
