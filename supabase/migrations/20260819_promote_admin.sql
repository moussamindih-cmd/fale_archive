-- ==========================================
-- PROMOTION D'UN UTILISATEUR EN ADMIN
-- ==========================================

-- Instructions :
-- 1. Créez un compte dans l'application avec l'email 'admin@fale.com' (ou un autre email).
-- 2. Exécutez cette requête dans le SQL Editor de Supabase pour le transformer en Administrateur Supérieur.

UPDATE public.employees 
SET role = 'admin' 
WHERE email = 'admin@fale.com';

-- Si vous avez utilisé une autre adresse email pour l'admin, changez 'admin@fale.com' par votre adresse.
