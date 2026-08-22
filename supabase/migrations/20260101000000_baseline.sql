-- =====================================================================
-- 20260101000000_baseline.sql
-- Schéma de référence des tables métier.
--
-- Ces six tables ont été créées à la main dans le tableau de bord Supabase
-- et n'existaient dans aucune migration : `20260817_init_saas.sql:17`
-- l'assumait explicitement (« Assuming tables already exist »). La base
-- n'était donc pas reproductible — `supabase db reset` échouait dès le
-- premier ALTER TABLE, et les contraintes réellement en production étaient
-- inconnues.
--
-- Déclaré en CREATE TABLE IF NOT EXISTS : sans effet sur l'instance
-- existante, reconstruit tout sur une base neuve.
--
-- IMPORTANT — à confronter au schéma réellement en production avant
-- application :
--   pg_dump --schema-only --no-owner --no-privileges "$DB_URL" > reel.sql
-- Toute divergence (type, NOT NULL, valeur par défaut) doit être reportée
-- ici, car c'est ce fichier qui fera foi ensuite.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- organizations — le tenant
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.organizations (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- Colonnes lues par le client mais absentes de la migration d'origine
-- (`theme_state.dart` pour la personnalisation, `supabase_service` à
-- l'inscription).
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS admin_id uuid;
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS primary_color text;
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS logo_url text;

-- ---------------------------------------------------------------------
-- employees — le profil applicatif, adossé à auth.users
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employees (
    id              uuid PRIMARY KEY,           -- = auth.uid()
    organization_id uuid REFERENCES public.organizations(id),
    full_name       text NOT NULL DEFAULT '',
    email           text NOT NULL,
    personal_email  text,
    -- Vestige d'avant Supabase Auth : le client y écrit une chaîne vide.
    -- Conservée pour ne pas casser les insertions, à retirer une fois le
    -- code nettoyé.
    password_hash   text NOT NULL DEFAULT '',
    job_title       text NOT NULL DEFAULT '',
    role            text NOT NULL DEFAULT 'employe',
    is_active       boolean NOT NULL DEFAULT true,
    avatar_url      text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS employees_email_key ON public.employees (lower(email));
CREATE INDEX IF NOT EXISTS employees_org ON public.employees (organization_id);

-- ---------------------------------------------------------------------
-- daily_archives — l'archive journalière (§5.1)
-- ---------------------------------------------------------------------
-- `id` est du TEXTE et non un uuid : le client génère `arc_<millis>`
-- (`app_state.dart:412`). Deux dépôts dans la même milliseconde entrent
-- donc en collision, et les identifiants sont énumérables — à reprendre
-- dans un lot dédié, la bascule vers uuid touchant des données existantes.
CREATE TABLE IF NOT EXISTS public.daily_archives (
    id                text PRIMARY KEY,
    organization_id   uuid NOT NULL REFERENCES public.organizations(id),
    employee_id       uuid REFERENCES public.employees(id),
    employee_name     text NOT NULL DEFAULT '',
    job_title         text NOT NULL DEFAULT '',
    archive_date      date NOT NULL,
    title             text NOT NULL DEFAULT '',
    summary           text NOT NULL DEFAULT '',
    category          text NOT NULL DEFAULT '',
    document_count    integer NOT NULL DEFAULT 0,
    physical_location text,
    documents         jsonb NOT NULL DEFAULT '[]'::jsonb,
    submitted_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at        timestamptz
);

CREATE INDEX IF NOT EXISTS daily_archives_org_date
    ON public.daily_archives (organization_id, archive_date DESC);
CREATE INDEX IF NOT EXISTS daily_archives_employee
    ON public.daily_archives (employee_id, archive_date DESC);
-- La corbeille est filtrée sur `deleted_at IS NULL` à chaque chargement.
CREATE INDEX IF NOT EXISTS daily_archives_live
    ON public.daily_archives (organization_id, submitted_at DESC)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- candidates — le vivier RH (§5.3)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.candidates (
    id               text PRIMARY KEY,          -- `cand_<millis>`
    organization_id  uuid NOT NULL REFERENCES public.organizations(id),
    full_name        text NOT NULL,
    target_position  text NOT NULL DEFAULT '',
    email            text,
    phone            text,
    application_date timestamptz NOT NULL DEFAULT now(),
    status           text NOT NULL DEFAULT 'enAttente',
    rh_notes         text NOT NULL DEFAULT '',
    documents        jsonb NOT NULL DEFAULT '[]'::jsonb,
    is_deleted       boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS candidates_org_date
    ON public.candidates (organization_id, application_date DESC);

-- ---------------------------------------------------------------------
-- logistics_items — pièces et factures
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.logistics_items (
    id                 text PRIMARY KEY,        -- `log_<millis>`
    organization_id    uuid NOT NULL REFERENCES public.organizations(id),
    document_type      text NOT NULL DEFAULT 'autre',
    reference          text NOT NULL DEFAULT '',
    amount             numeric,
    supplier           text NOT NULL DEFAULT '',
    issue_date         timestamptz NOT NULL DEFAULT now(),
    status             text NOT NULL DEFAULT 'enAttente',
    registered_by_id   uuid REFERENCES public.employees(id),
    registered_by_name text NOT NULL DEFAULT '',
    validated_by_name  text,
    notes              text NOT NULL DEFAULT '',
    documents          jsonb NOT NULL DEFAULT '[]'::jsonb,
    is_deleted         boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS logistics_org_date
    ON public.logistics_items (organization_id, issue_date DESC);

-- ---------------------------------------------------------------------
-- action_history_entries — journal d'activité historique
-- ---------------------------------------------------------------------
-- Remplacé par `audit_logs` (migration 20260822000100) : cette table reste
-- en lecture pour les données déjà écrites, mais ne doit plus recevoir
-- d'écriture nouvelle.
CREATE TABLE IF NOT EXISTS public.action_history_entries (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id    uuid REFERENCES public.organizations(id),
    user_name          text NOT NULL DEFAULT '',
    action             text NOT NULL,
    details            text NOT NULL DEFAULT '',
    timestamp          timestamptz NOT NULL DEFAULT now(),
    candidate_id       text REFERENCES public.candidates(id),
    logistics_item_id  text REFERENCES public.logistics_items(id)
);

ALTER TABLE public.action_history_entries
    ADD COLUMN IF NOT EXISTS employee_id uuid REFERENCES public.employees(id);

CREATE INDEX IF NOT EXISTS action_history_org_time
    ON public.action_history_entries (organization_id, timestamp DESC);

-- ---------------------------------------------------------------------
-- in_app_notifications — notifications applicatives (§5.3.4)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.in_app_notifications (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id   uuid NOT NULL REFERENCES public.organizations(id),
    title             text NOT NULL,
    message           text NOT NULL DEFAULT '',
    type              text NOT NULL DEFAULT 'system',
    timestamp         timestamptz NOT NULL DEFAULT now(),
    is_read           boolean NOT NULL DEFAULT false,
    related_entity_id text,
    target_role       text,
    target_user_id    uuid REFERENCES public.employees(id)
);

CREATE INDEX IF NOT EXISTS notifications_target
    ON public.in_app_notifications (organization_id, target_user_id, is_read);
