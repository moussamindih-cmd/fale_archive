-- =====================================================================
-- 20260817_init_saas.sql
-- Migration script to introduce SaaS Organizations, Subscriptions and RLS
-- =====================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create organizations table
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Add organization_id to existing tables
-- Assuming tables already exist. We add the column and make it nullable initially
-- to avoid breaking existing data, then we will assign a default organization.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='organization_id') THEN
        ALTER TABLE public.employees ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_archives' AND column_name='organization_id') THEN
        ALTER TABLE public.daily_archives ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='candidates' AND column_name='organization_id') THEN
        ALTER TABLE public.candidates ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='logistics_items' AND column_name='organization_id') THEN
        ALTER TABLE public.logistics_items ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='action_history_entries' AND column_name='organization_id') THEN
        ALTER TABLE public.action_history_entries ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='in_app_notifications' AND column_name='organization_id') THEN
        ALTER TABLE public.in_app_notifications ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
    END IF;
END $$;

-- 3. Create a default organization for existing data
DO $$
DECLARE
    default_org_id UUID;
BEGIN
    -- Check if we already have a default organization
    SELECT id INTO default_org_id FROM public.organizations WHERE name = 'Default Dev Organization' LIMIT 1;
    
    IF default_org_id IS NULL THEN
        INSERT INTO public.organizations (name) VALUES ('Default Dev Organization') RETURNING id INTO default_org_id;
    END IF;

    -- Update existing records to the default organization
    UPDATE public.employees SET organization_id = default_org_id WHERE organization_id IS NULL;
    UPDATE public.daily_archives SET organization_id = default_org_id WHERE organization_id IS NULL;
    UPDATE public.candidates SET organization_id = default_org_id WHERE organization_id IS NULL;
    UPDATE public.logistics_items SET organization_id = default_org_id WHERE organization_id IS NULL;
    UPDATE public.action_history_entries SET organization_id = default_org_id WHERE organization_id IS NULL;
    UPDATE public.in_app_notifications SET organization_id = default_org_id WHERE organization_id IS NULL;

    -- Now that we have assigned orgs, we can make the columns NOT NULL
    ALTER TABLE public.employees ALTER COLUMN organization_id SET NOT NULL;
    ALTER TABLE public.daily_archives ALTER COLUMN organization_id SET NOT NULL;
    ALTER TABLE public.candidates ALTER COLUMN organization_id SET NOT NULL;
    ALTER TABLE public.logistics_items ALTER COLUMN organization_id SET NOT NULL;
    ALTER TABLE public.action_history_entries ALTER COLUMN organization_id SET NOT NULL;
    ALTER TABLE public.in_app_notifications ALTER COLUMN organization_id SET NOT NULL;
END $$;

-- 4. Create Subscription Tables
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    amount NUMERIC NOT NULL,
    currency TEXT NOT NULL DEFAULT 'XAF',
    duration_days INT NOT NULL DEFAULT 30,
    features JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT NOT NULL DEFAULT 0,
    max_users INT NOT NULL DEFAULT 1,
    max_storage_mb INT NOT NULL DEFAULT 500,
    grace_period_days INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Make sure missing columns are added if table already existed
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscription_plans' AND column_name='max_users') THEN
        ALTER TABLE public.subscription_plans ADD COLUMN max_users INT NOT NULL DEFAULT 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscription_plans' AND column_name='max_storage_mb') THEN
        ALTER TABLE public.subscription_plans ADD COLUMN max_storage_mb INT NOT NULL DEFAULT 500;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscription_plans' AND column_name='grace_period_days') THEN
        ALTER TABLE public.subscription_plans ADD COLUMN grace_period_days INT NOT NULL DEFAULT 0;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id),
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id),
    amount NUMERIC NOT NULL,
    currency TEXT NOT NULL DEFAULT 'XAF',
    operator TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    transaction_reference TEXT,
    payment_status TEXT NOT NULL DEFAULT 'pending', -- pending, paid, failed, expired
    expires_at TIMESTAMPTZ,
    activated_at TIMESTAMPTZ,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.subscription_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES public.subscriptions(id),
    old_status TEXT NOT NULL,
    new_status TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert some default plans
INSERT INTO public.subscription_plans (name, description, amount, max_users, features, sort_order)
VALUES 
    ('Starter', 'Idéal pour les petites équipes', 15000, 5, '["10_utilisateurs", "archivage_quotidien"]', 1),
    ('Pro', 'Pour les PME en croissance', 35000, 20, '["10_utilisateurs", "archivage_illimite", "gestion_candidats"]', 2),
    ('Enterprise', 'Solution complète illimitée', 75000, 9999, '["utilisateurs_illimites", "archivage_illimite", "gestion_candidats", "logistique", "rapports_avances"]', 3)
ON CONFLICT DO NOTHING;

-- 5. Row Level Security (RLS)

-- Secure function to get current user's organization_id without causing recursion
CREATE OR REPLACE FUNCTION public.current_user_organization_id()
RETURNS UUID AS $$
    SELECT organization_id FROM public.employees WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Enable RLS on all relevant tables
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.action_history_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.in_app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any to prevent conflicts
DO $$
DECLARE
    table_list TEXT[] := ARRAY['organizations', 'employees', 'daily_archives', 'candidates', 'logistics_items', 'action_history_entries', 'in_app_notifications', 'subscriptions'];
    t TEXT;
BEGIN
    FOREACH t IN ARRAY table_list
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Isolation par organisation" ON %I', t);
    END LOOP;
END $$;

-- Organizations policy: users can only see their own organization
CREATE POLICY "Isolation par organisation" ON public.organizations
    FOR ALL USING (id = public.current_user_organization_id());

-- Subscriptions policy
CREATE POLICY "Isolation par organisation" ON public.subscriptions
    FOR ALL USING (organization_id = public.current_user_organization_id());

-- Create policies for entity tables to only access rows where organization_id matches
CREATE POLICY "Isolation par organisation" ON public.employees
    FOR ALL USING (organization_id = public.current_user_organization_id());

CREATE POLICY "Isolation par organisation" ON public.daily_archives
    FOR ALL USING (organization_id = public.current_user_organization_id());

CREATE POLICY "Isolation par organisation" ON public.candidates
    FOR ALL USING (organization_id = public.current_user_organization_id());

CREATE POLICY "Isolation par organisation" ON public.logistics_items
    FOR ALL USING (organization_id = public.current_user_organization_id());

CREATE POLICY "Isolation par organisation" ON public.action_history_entries
    FOR ALL USING (organization_id = public.current_user_organization_id());

CREATE POLICY "Isolation par organisation" ON public.in_app_notifications
    FOR ALL USING (organization_id = public.current_user_organization_id());

-- Note: The Edge functions (e.g. SupabaseService.signUp) use the Service Role Key
-- which bypasses RLS. This is good because new users don't have an org yet, 
-- and the backend will handle creating the org and the employee profile securely.
