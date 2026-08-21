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
set -euo pipefail
cd "$(dirname "$0")"

exec flutter run -d web-server \
  --web-hostname=127.0.0.1 \
  --web-port=5000 \
  --pid-file=/tmp/fale_dev.pid
