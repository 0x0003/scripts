#!/usr/bin/env bash
usage() { echo "Usage: $(basename "$0") <host> [port] [output_file]"; echo "  Extracts a QUIC (HTTP/3) TLS 1.3 ClientHello to a binary file"; exit 1; }
[[ $# -eq 0 ]] && usage
HOST="$1"; PORT="${2:-443}"; OUT="${3:-quic_${HOST%%.*}.bin}"

echo | openssl s_client -quic -connect "$HOST:$PORT" -alpn h3 -msg 2>&1 | \
  awk '/>>> TLS 1.3, Handshake.*ClientHello/{p=1; next} p && /^[<>]/{exit} p' | \
  sed 's/^  *//g' | tr '\n' ' ' | \
  python3 -c "
import sys
data = bytes.fromhex(''.join(sys.stdin.read().split()))
sys.stdout.buffer.write(data)
" > "$OUT" 2>/dev/null

wc -c < "$OUT" | (read n; echo "Wrote $OUT ($n bytes)")
