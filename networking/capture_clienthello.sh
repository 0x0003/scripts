#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: ${0##*/} [-t|-q|-a] example.com
Options:
  -t  Capture TLS ClientHello (default)
  -q  Capture QUIC Initial
  -a  Capture both TLS and QUIC
EOF
  exit 1
}

MODE=tls
while getopts "tqa" opt; do
  case $opt in
    t) MODE=tls ;;
    q) MODE=quic ;;
    a) MODE=all ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))
[ -z "$1" ] && usage

TOOL=curl # supported: curl (Debian 13 Trixie), gocurl
DOMAIN="$1"
TLS_FILE="tls_clienthello_${DOMAIN//./_}.bin"
QUIC_FILE="quic_initial_${DOMAIN//./_}.bin"
LOG_FILE="${DOMAIN//./_}.socat.log"

cleanup() {
  pids=$(pgrep -f "socat.*-LISTEN:*" | tr '\n' ' ')
  [ -n "$pids" ] && kill -TERM $pids 2>/dev/null
  rm -f "$LOG_FILE"
}

show_result() {
  local file="$1"
  local type="$2"
  [ -s "$file" ] || { echo -e "\n❌ No $type captured"; rm -f "$file"; return 1; }

  cat <<EOF
✅ $type saved to $file
Size: $(wc -c < "$file") bytes
First 32 bytes:
$(hexdump -C -n 32 "$file" | head -n 2)
EOF
}

capture_tls() {
  local port=$((RANDOM % 63001 + 2000))
  local curl_opts=(--tlsv1.3 -k --connect-to $DOMAIN:443:127.0.0.1:$port -k https://$DOMAIN)
  local curl_cmd

  case "$TOOL" in
    curl*)  curl_cmd=(-IS "${curl_opts[@]}") ;;
    gocurl) curl_cmd=(-I "${curl_opts[@]}") ;;
    *)      echo "❌ Unknown tool: $TOOL (supported: curl, gocurl)" >&2; return 1 ;;
  esac

  socat TCP-LISTEN:"$port",reuseaddr,shut-none - > "$TLS_FILE" & sleep 0.5

  $TOOL "${curl_cmd[@]}" >/dev/null 2>&1 || true

  show_result "$TLS_FILE" "TLS ClientHello"
}

capture_quic() {
  local port=$((RANDOM % 63001 + 2000))
  local ip retries=10 attempt=1 tmp_file="${QUIC_FILE}.tmp"
  local curl_opts=(-k --connect-to $DOMAIN:443:127.0.0.1:$port -k https://$DOMAIN)
  local size pkt_length pkt_from curl_cmd

  case "$TOOL" in
    curl*)
      if [ -n "${TERMUX_VERSION:-}" ]; then
        pkt_length=1200 pkt_from=0
      else
        pkt_length=1200 pkt_from=1200
      fi
      curl_cmd=(-IS --http3-only "${curl_opts[@]}")
      ;;
    gocurl)
      pkt_length=1252 pkt_from=0
      curl_cmd=(-I --http3 "${curl_opts[@]}")
      ;;
    *)
      echo "❌ Unknown tool: $TOOL (supported: curl, gocurl)"
      return 1
      ;;
  esac

  local pkt_to=$((pkt_from + pkt_length - 1))

  ip=$(ping -4 -c 1 "$DOMAIN" | awk -F'[()]' '/PING/{ print $2 }')
  [ -z "$ip" ] && { echo "❌ Cannot resolve $DOMAIN"; return 1; }
  socat -v -x UDP4-LISTEN:$port,reuseaddr,fork UDP4:$ip:443 > "$LOG_FILE" 2>&1 & sleep 0.5
  while [ $attempt -le $retries ]; do
    echo "🔄 QUIC Initial capture attempt #$attempt"
    rm -f "$tmp_file"
    $TOOL "${curl_cmd[@]}" >/dev/null 2>&1 || true
    if awk -v len="$pkt_length" -v fr="$pkt_from" -v to="$pkt_to" '
      $0 ~ /^> .*length=[0-9]+ from=[0-9]+ to=[0-9]+$/ {
        if ($0 ~ "length=" len " from=" fr " to=" to) { flag=1; next }
      }
      flag && /^--$/ { exit }
      flag { print substr($0,2,48) }
      ' "$LOG_FILE" | tr -d ' \n' | xxd -r -p > "$tmp_file"
    then
      size=$(wc -c < "$tmp_file" 2>/dev/null || echo 0)
      if [ "$size" -eq "$pkt_length" ]; then
        mv "$tmp_file" "$QUIC_FILE"
        show_result "$QUIC_FILE" "QUIC Initial"
        return 0
      else
        echo "❌ Received $size bytes (need $pkt_length), retrying..."
      fi
    else
      echo "❌ Failed to extract QUIC Initial on attempt #$attempt"
    fi
    ((attempt++))
  done
  echo -e "\n❌ All $retries attempts failed to capture ${pkt_length}-byte QUIC Initial"
  return 1
}
trap cleanup EXIT INT TERM
case $MODE in
  tls) capture_tls ;;
  quic) capture_quic ;;
  all) capture_tls; capture_quic ;;
esac
