#!/usr/bin/env bash
set -euo pipefail

# --- Params (override via env) ---
HOST="${HOST:-grafana.nudger.logo-solutions.fr}"            # FQDN de l'Ingress
PATH_CHECK="${PATH_CHECK:-/}"                  # Chemin à tester (ex: /login)
SCHEME="${SCHEME:-http}"                      # http|https
PORT="${PORT:-80}"                               # vide => par défaut (80/443). Exemple pour NodePort: 30443 avec SCHEME=https
EXPECT_CODES="${EXPECT_CODES:-200,302}"        # Liste de codes autorisés séparés par des virgules
EXPECT_BODY_REGEX="${EXPECT_BODY_REGEX:-}"     # Optionnel: regex à trouver dans la réponse
INSECURE="${INSECURE:-true}"                   # true => ignore cert (curl -k)
FOLLOW_REDIRECTS="${FOLLOW_REDIRECTS:-true}"   # true => -L
RETRIES="${RETRIES:-15}"
SLEEP_SECONDS="${SLEEP_SECONDS:-4}"
TIMEOUT="${TIMEOUT:-10}"                       # timeout curl par tentative (s)
RESOLVE_IP="${RESOLVE_IP:-91.98.16.184}"                   # Ex: 91.98.16.184 (forçage DNS: --resolve host:port:ip)

# --- Build URL & curl opts ---
if [[ -z "$PORT" ]]; then
  URL="${SCHEME}://${HOST}${PATH_CHECK}"
  RESOLVE_PORT="$([[ "$SCHEME" == "https" ]] && echo 443 || echo 80)"
else
  URL="${SCHEME}://${HOST}:${PORT}${PATH_CHECK}"
  RESOLVE_PORT="$PORT"
fi

CURL_OPTS=(-s -S --show-error --max-time "$TIMEOUT" -o /tmp/smoke_body -w "%{http_code}")
[[ "$INSECURE" == "true" ]] && CURL_OPTS+=(-k)
[[ "$FOLLOW_REDIRECTS" == "true" ]] && CURL_OPTS+=(-L)

if [[ -n "$RESOLVE_IP" ]]; then
  CURL_OPTS+=(--resolve "${HOST}:${RESOLVE_PORT}:${RESOLVE_IP}")
fi

echo "🔎 Smoke test Ingress NGINX"
echo "   URL:            $URL"
echo "   HOST:           $HOST"
echo "   EXPECT_CODES:   $EXPECT_CODES"
[[ -n "$EXPECT_BODY_REGEX" ]] && echo "   EXPECT_BODY:    /${EXPECT_BODY_REGEX}/"
[[ -n "$RESOLVE_IP" ]] && echo "   --resolve ${HOST}:${RESOLVE_PORT}:${RESOLVE_IP}"
echo "   RETRIES x SLEEP: ${RETRIES} x ${SLEEP_SECONDS}s"
echo

# --- Helper: check code in list ---
in_list() {
  local needle="$1"
  local list="$2"
  IFS=',' read -ra arr <<< "$list"
  for x in "${arr[@]}"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

# --- Loop tries ---
for try in $(seq 1 "$RETRIES"); do
  echo "Attempt ${try}/${RETRIES} … curl ${CURL_OPTS[@]} $URL"
  HTTP_CODE="$(curl "${CURL_OPTS[@]}" -D /tmp/smoke_headers "$URL" || true)"
  echo "HTTP_CODE=${HTTP_CODE}"

  if in_list "$HTTP_CODE" "$EXPECT_CODES"; then
    if [[ -n "$EXPECT_BODY_REGEX" ]]; then
      if grep -E -q "${EXPECT_BODY_REGEX}" /tmp/smoke_body; then
        echo "✅ Body matched regex '${EXPECT_BODY_REGEX}'"
        exit 0
      else
        echo "ℹ️  Code ok mais body ne matche pas '${EXPECT_BODY_REGEX}'"
      fi
    else
      echo "✅ Code HTTP attendu"
      exit 0
    fi
  else
    echo "ℹ️  Code inattendu (${HTTP_CODE}), on réessaie…"
  fi

  # Petit diagnostic utile
  echo "— Headers —"
  sed -n '1,20p' /tmp/smoke_headers || true
  echo "— Body (first 200 chars) —"
  head -c 200 /tmp/smoke_body || true
  echo; echo

  sleep "$SLEEP_SECONDS"
done

echo "❌ Échec: impossible d’obtenir un code attendu (${EXPECT_CODES})"
exit 1
