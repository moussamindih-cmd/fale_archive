# Scripts d'exploitation

Ces scripts ne sont **pas** des migrations : ils ne doivent jamais être placés
dans `supabase/migrations/`, sinon ils se rejouent à chaque `supabase db push`.

- `promote_admin.sql` — promeut un compte au rôle `admin`. Déplacé depuis
  `migrations/20260819_promote_admin.sql`, où il repromouvait silencieusement
  `admin@fale.com` à chaque déploiement.

Exécution :

```bash
psql "$DB_URL" -f supabase/scripts/promote_admin.sql
```
