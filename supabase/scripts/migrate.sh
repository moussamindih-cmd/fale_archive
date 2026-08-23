#!/usr/bin/env bash
#
# Application des migrations sur l'instance Supabase.
#
# Ce script ne pousse RIEN sans avoir d'abord : sauvegardé la base, capturé
# le schéma réel, et rejoué l'intégralité des migrations sur une copie
# restaurée. La production n'est touchée qu'à la dernière étape, après une
# confirmation explicite.
#
# Prérequis — à définir dans le shell, jamais dans un fichier versionné :
#
#   export SUPABASE_DB_URL='postgresql://postgres.<ref>:<mot-de-passe>@aws-0-<region>.pooler.supabase.com:5432/postgres'
#
# Où le trouver : tableau de bord Supabase → Project Settings → Database
#                 → Connection string → URI (mode "Session", port 5432).
#
# Usage :
#   ./supabase/scripts/migrate.sh check     # étapes 1 à 3, ne touche à rien
#   ./supabase/scripts/migrate.sh dry-run   # + rejeu sur une copie locale
#   ./supabase/scripts/migrate.sh apply     # + application en production
#
set -euo pipefail
cd "$(dirname "$0")/../.."

MODE="${1:-check}"
WORK="${TMPDIR:-/tmp}/fale-migration-$(date +%Y%m%d-%H%M%S)"
LOCAL_PORT=55440
MIGRATIONS=(supabase/migrations/*.sql)

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
green(){ printf '\033[32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  red "SUPABASE_DB_URL n'est pas défini."
  echo "  export SUPABASE_DB_URL='postgresql://postgres.<ref>:<mdp>@...pooler.supabase.com:5432/postgres'"
  exit 1
fi

mkdir -p "$WORK"
bold "Répertoire de travail : $WORK"

# ─── 1. Sauvegarde complète ───────────────────────────────────────────────
# Toujours en premier. Sans sauvegarde utilisable, rien de ce qui suit ne
# doit être tenté.
bold $'\n[1/5] Sauvegarde complète (schéma + données)'
pg_dump "$SUPABASE_DB_URL" --no-owner --no-privileges -Fc -f "$WORK/backup.dump"
green "  ✓ $WORK/backup.dump ($(du -h "$WORK/backup.dump" | cut -f1))"

# ─── 2. Capture du schéma réel ────────────────────────────────────────────
bold $'\n[2/5] Capture du schéma réel'
pg_dump "$SUPABASE_DB_URL" --schema-only --no-owner --no-privileges \
        --schema=public -f "$WORK/schema-reel.sql"
green "  ✓ $WORK/schema-reel.sql"

# ─── 3. Confrontation à la baseline ───────────────────────────────────────
# La baseline a été reconstituée à partir du code Dart, faute d'accès à la
# base. C'est une hypothèse : cette étape est la seule qui la vérifie.
bold $'\n[3/5] Confrontation baseline ↔ production'
MISSING=0
for t in employees daily_archives candidates logistics_items \
         action_history_entries in_app_notifications organizations; do
  if grep -q "CREATE TABLE public.$t" "$WORK/schema-reel.sql"; then
    echo "  · $t : présente en production"
    # Colonnes réelles vs colonnes déclarées dans la baseline
    awk "/CREATE TABLE public\.$t /,/^\);/" "$WORK/schema-reel.sql" \
      | grep -oP '^\s+\K[a-z_]+' | sort > "$WORK/$t.reel.txt"
    awk "/CREATE TABLE IF NOT EXISTS public\.$t /,/^\);/" \
        supabase/migrations/20260101000000_baseline.sql \
      | grep -oP '^\s+\K[a-z_]+' | grep -vE '^(CONSTRAINT|UNIQUE|PRIMARY|CHECK)$' \
      | sort > "$WORK/$t.baseline.txt"
    if ! diff -q "$WORK/$t.reel.txt" "$WORK/$t.baseline.txt" >/dev/null; then
      red "    ⚠ divergence de colonnes :"
      diff "$WORK/$t.reel.txt" "$WORK/$t.baseline.txt" | sed 's/^/      /' || true
      MISSING=1
    fi
  else
    red "  · $t : ABSENTE de la production"
    MISSING=1
  fi
done

if [[ $MISSING -eq 1 ]]; then
  red $'\n  Des divergences existent. Reportez-les dans'
  red '  supabase/migrations/20260101000000_baseline.sql AVANT de continuer.'
  red '  C’est ce fichier qui fera foi ensuite.'
  [[ "$MODE" == "check" ]] || exit 1
else
  green "  ✓ La baseline correspond au schéma réel"
fi

[[ "$MODE" == "check" ]] && { bold $'\nMode « check » : rien n’a été modifié.'; exit 0; }

# ─── 4. Rejeu sur une copie restaurée ─────────────────────────────────────
# Les migrations 5 à 13 modifient des données existantes (reprise des
# candidats, reversement des notes RH, migration de l'audit). Les jouer
# d'abord sur une copie est la seule façon de savoir ce qu'elles feront.
bold $'\n[4/5] Rejeu sur une copie restaurée'
export PATH="/usr/lib/postgresql/18/bin:$PATH"
PGDATA_LOCAL="$WORK/pgdata"
initdb -D "$PGDATA_LOCAL" -U postgres --auth=trust >/dev/null
pg_ctl -D "$PGDATA_LOCAL" -o "-p $LOCAL_PORT -k /tmp -c listen_addresses=''" \
       -l "$WORK/pg.log" start >/dev/null
trap 'pg_ctl -D "$PGDATA_LOCAL" stop -m fast >/dev/null 2>&1 || true' EXIT
sleep 2

psql -h /tmp -p $LOCAL_PORT -U postgres -q -c "CREATE DATABASE copie;"
pg_restore -h /tmp -p $LOCAL_PORT -U postgres -d copie --no-owner \
           --no-privileges "$WORK/backup.dump" >/dev/null 2>&1 || true
green "  ✓ copie restaurée"

for f in "${MIGRATIONS[@]}"; do
  printf '  · %-48s ' "$(basename "$f")"
  if psql -h /tmp -p $LOCAL_PORT -U postgres -d copie -q -v ON_ERROR_STOP=1 \
          -f "$f" >"$WORK/$(basename "$f").log" 2>&1; then
    green "OK"
  else
    red "ÉCHEC"
    sed -n '1,15p' "$WORK/$(basename "$f").log"
    red $'\n  Corrigez la migration avant toute application en production.'
    exit 1
  fi
done
green "  ✓ Les 13 migrations passent sur une copie des données réelles"

# Ce que la reprise a produit, à relire avant de pousser.
bold $'\n  Effets de la reprise de données :'
psql -h /tmp -p $LOCAL_PORT -U postgres -d copie -t -A -F' | ' <<'SQL'
SELECT '  candidatures créées : ' || count(*) FROM applications;
SELECT '  avis repris        : ' || count(*) FROM application_notes;
SELECT '  lignes d''audit     : ' || count(*) FROM audit_logs;
SELECT '  étapes de pipeline : ' || count(*) FROM pipeline_stages;
SQL

[[ "$MODE" == "dry-run" ]] && { bold $'\nMode « dry-run » : la production n’a pas été touchée.'; exit 0; }

# ─── 5. Application en production ─────────────────────────────────────────
bold $'\n[5/5] Application en production'
red "  Cette étape modifie des données réelles."
echo "  Sauvegarde disponible : $WORK/backup.dump"
read -r -p "  Taper exactement APPLIQUER pour continuer : " CONFIRM
[[ "$CONFIRM" == "APPLIQUER" ]] || { echo "  Annulé."; exit 0; }

for f in "${MIGRATIONS[@]}"; do
  printf '  · %-48s ' "$(basename "$f")"
  # Chaque migration dans sa propre transaction : un échec n'en laisse
  # aucune à moitié appliquée.
  if psql "$SUPABASE_DB_URL" -q -v ON_ERROR_STOP=1 --single-transaction \
          -f "$f" >"$WORK/prod-$(basename "$f").log" 2>&1; then
    green "OK"
  else
    red "ÉCHEC"
    sed -n '1,15p' "$WORK/prod-$(basename "$f").log"
    red $'\n  Migration annulée (transaction non validée).'
    red "  Restauration si nécessaire :"
    red "    pg_restore -d \"\$SUPABASE_DB_URL\" --clean --if-exists $WORK/backup.dump"
    exit 1
  fi
done

green $'\n  ✓ Migrations appliquées.'
echo "  Sauvegarde conservée : $WORK/backup.dump"
