#!/usr/bin/env bash
set -euo pipefail

# ---------- Params ----------
HOST="${HOST:-grafana.nudger.logo-solutions.fr}"            # FQDN de l'Ingress
SCHEME="${SCHEME:-https}"                      # http|https
PORT="${PORT:-30443}"
PATH_CHECK="${PATH_CHECK:-/}"        # chemin à tester
RESOLVE_IP="${RESOLVE_IP:-91.98.16.184}"         # force DNS: --resolve host:port:ip
EXPECT_CODES="${EXPECT_CODES:-200,301,302}"  # codes acceptés
# Acceptes aussi quels codes pour le test de redirection HTTP->HTTPS
REDIRECT_EXPECT="${REDIRECT_EXPECT:-301,302,308}"

INSECURE="${INSECURE:-true}"         # -k
FOLLOW_REDIRECTS="${FOLLOW_REDIRECTS:-true}"
RETRIES="${RETRIES:-10}"
SLEEP_SECONDS="${SLEEP_SECONDS:-3}"
TIMEOUT="${TIMEOUT:-10}"

# Checks toggles (true|false)
CHECK_REACH="${CHECK_REACH:-true}"
CHECK_REDIRECT="${CHECK_REDIRECT:-true}"
CHECK_TLS="${CHECK_TLS:-true}"
CHECK_GZIP="${CHECK_GZIP:-true}"

# ---------- Build URL ----------
if [[ -z "${PORT}" ]]; then
  URL="${SCHEME}://${HOST}${PATH_CHECK}"
  RESOLVE_PORT="$([[ "$SCHEME" == "https" ]] && echo 443 || echo 80)"
else
  URL="${SCHEME}://${HOST}:${PORT}${PATH_CHECK}"
  RESOLVE_PORT="$PORT"
fi

# ---------- Curl opts ----------
CLEANUP_FILES=()
BODY="$(mktemp)"; CLEANUP_FILES+=("$BODY")
HEADERS="$(mktemp)"; CLEANUP_FILES+=("$HEADERS")
trap 'rm -f "${CLEANUP_FILES[@]}" 2>/dev/null || true' EXIT
CURL_OPTS=(-s -S --show-error --max-time "$TIMEOUT" -o "$BODY" -w "%{http_code}")
[[ "$INSECURE" == "true" ]] && CURL_OPTS+=(-k)
[[ "$FOLLOW_REDIRECTS" == "true" ]] && CURL_OPTS+=(-L)
[[ -n "$RESOLVE_IP" ]] && CURL_OPTS+=(--resolve "${HOST}:${RESOLVE_PORT}:${RESOLVE_IP}")

echo "🔎 NGINX Ingress smoke"
echo "   URL:  $URL"
echo "   HOST: $HOST"
[[ -n "$RESOLVE_IP" ]] && echo "   --resolve ${HOST}:${RESOLVE_PORT}:${RESOLVE_IP}"
echo

in_list(){ local n="$1" l="$2"; IFS=',' read -ra a <<< "$l"; for x in "${a[@]}"; do [[ "$x" == "$n" ]] && return 0; done; return 1; }

# ---------- CHECK_REACH ----------
if [[ "$CHECK_REACH" == "true" ]]; then
  for i in $(seq 1 "$RETRIES"); do
    echo "🌐 REACH attempt $i/$RETRIES …"
    : > "$BODY"; : > "$HEADERS"
    HTTP_CODE="$(curl "${CURL_OPTS[@]}" -D "$HEADERS" "$URL" || true)"
    if [[ "$HTTP_CODE" == "000" ]]; then
      echo "❗️ Connexion impossible (port fermé / FW)."
    elif in_list "$HTTP_CODE" "$EXPECT_CODES"; then
      echo "✅ REACH ok (HTTP $HTTP_CODE)"
      break
    else
      echo "ℹ️ REACH code inattendu: $HTTP_CODE"
    fi
    sed -n '1,20p' "$HEADERS" || true; echo
    sleep "$SLEEP_SECONDS"
    [[ "$i" -eq "$RETRIES" ]] && { echo "❌ REACH KO"; exit 1; }
  done
fi

# ---------- CHECK_REDIRECT (HTTP -> HTTPS) ----------
if [[ "$CHECK_REDIRECT" == "true" ]]; then
  if [[ "$SCHEME" == "https" ]]; then
    # On teste le endpoint HTTP (80 par défaut, ou NodePort HTTP si on devine un pair 30443→30080)
    if [[ -n "${PORT:-}" ]]; then
      case "$PORT" in
        443)   local_port=80 ;;
        30443) local_port=30080 ;;   # pair NodePort le plus courant
        *)     local_port=80 ;;      # fallback
      esac
    else
      local_port=80
    fi
    local_url="http://${HOST}:${local_port}${PATH_CHECK}"
    local_curl=( -s -S --show-error --max-time "$TIMEOUT" -o /dev/null -w "%{http_code}" -I )
    [[ -n "$RESOLVE_IP" ]] && local_curl+=( --resolve "${HOST}:${local_port}:${RESOLVE_IP}" )
    code="$(curl "${local_curl[@]}" "$local_url" || true)"
    # Autoriser 301/302/308 (configurable via REDIRECT_EXPECT)
   if [[ ",$REDIRECT_EXPECT," == *",$code,"* ]]; then
      echo "✅ REDIRECT ok (HTTP -> HTTPS: $code)"
    else
      echo "❌ REDIRECT attendu (301/308) mais reçu: $code"
      # on n'échoue pas le job si ce n'est pas une politique requise
    fi
  fi
fi

# ---------- CHECK_TLS ----------
if [[ "$CHECK_TLS" == "true" && "$SCHEME" == "https" ]]; then
  # On interroge juste les headers
  tls_headers="$(mktemp)"
  tls_opts=(-s -S --show-error --max-time "$TIMEOUT" -I)
  [[ "$INSECURE" == "true" ]] && tls_opts+=(-k)
  [[ -n "$RESOLVE_IP" ]] && tls_opts+=(--resolve "${HOST}:${RESOLVE_PORT}:${RESOLVE_IP}")
  code="$(curl "${tls_opts[@]}" "https://${HOST}:${PORT:-443}${PATH_CHECK}" -D "$tls_headers" -o /dev/null -w "%{http_code}" || true)"
  if [[ "$code" =~ ^20[0-9]|30[0-9]$ ]]; then
    if grep -qi '^server: *nginx' "$tls_headers"; then
      echo "✅ TLS ok + header Server: nginx détecté"
    else
      echo "✅ TLS ok (attention: header Server différent ou masqué)"
    fi
  else
    echo "❌ TLS handshake/accès KO (code $code)"; exit 1
  fi
fi

# ---------- CHECK_GZIP ----------
if [[ "$CHECK_GZIP" == "true" ]]; then
  gzip_headers="$(mktemp)"
  gzip_code="$(curl -H 'Accept-Encoding: gzip' -I "${CURL_OPTS[@]}" -D "$gzip_headers" "$URL" -o /dev/null || true)"
  if grep -qi '^content-encoding: *gzip' "$gzip_headers"; then
    echo "✅ GZIP servi"
  else
    echo "ℹ️ Pas de GZIP (peut être volontaire)"
  fi
fi

echo "🎉 NGINX smoke: terminé."
