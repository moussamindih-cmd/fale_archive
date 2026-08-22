#!/usr/bin/env bash
#
# Lancement du serveur de développement FALE Archives.
#
# Toujours passer par ce script : des options de build identiques d'une session
# à l'autre garantissent que le cache de compilation incrémentale
# (build/<hash>.cache.dill.track.dill, ~85 Mo) est réutilisé au lieu d'être
# régénéré à froid.
#
# Une fois l'app ouverte dans le navigateur, ne PAS rafraîchir la page (F5) :
#   r  → hot reload  (l'état de l'app est conservé)
#   R  → hot restart (nécessaire après un changement dans main() ou une globale)
#   q  → quitter
#
# Hot reload depuis un autre terminal :
#   kill -SIGUSR1 $(cat /tmp/fale_dev.pid)   # hot reload
#   kill -SIGUSR2 $(cat /tmp/fale_dev.pid)   # hot restart
#
# Pour cibler un autre projet Supabase (staging, sandbox personnelle...) sans
# toucher au code, exporter avant de lancer ce script :
#   export SUPABASE_URL=https://xxxxx.supabase.co
#   export SUPABASE_ANON_KEY=sb_publishable_xxxxx
# Sans ces variables, le projet Supabase par défaut du dépôt est utilisé.
# Voir README.md.
#
set -euo pipefail
cd "$(dirname "$0")"

DART_DEFINES=()
if [[ -n "${SUPABASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
fi
if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
fi

exec flutter run -d web-server \
  --web-hostname=127.0.0.1 \
  --web-port=5000 \
  --pid-file=/tmp/fale_dev.pid \
  "${DART_DEFINES[@]}"
