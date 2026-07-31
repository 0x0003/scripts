#!/usr/bin/env bash
#
# Query MPD stickers of currently playing track; set rating.
# Pretty-printed stdout.

M='\e[35m'
R='\e[31m'
G='\e[32m'
Y='\e[33m'
B='\e[34m'
C='\e[36m'
N='\e[0m'

FILE=$(mpc current --format '%file%')

if [[ -z "$FILE" ]]; then
  echo "No track playing"
  exit 1
fi

print_status() {
  local value=$1 old=$2

  local artist title
  artist=$(mpc current --format '%artist%')
  title=$(mpc current --format '%title%')
  if [[ -n "$artist" ]]; then
    echo -e "${G}${artist}${N} • ${title}"
  else
    echo -e "${title}"
  fi
  echo "---"

  echo -n "Rated  "
  if [[ -n "$old" ]]; then
    echo -e "${R}${old}${N} -> ${G}${value}${N} stars"
  else
    echo -e "${G}${value}${N} stars"
  fi

  local play
  play=$(mpc sticker "$FILE" get playCount 2>/dev/null | sed 's/.*=//')
  if [[ -n "$play" ]]; then
    echo -e "Played ${Y}${play}${N} time(s)"
  fi

  local last
  last=$(mpc sticker "$FILE" get lastPlayed 2>/dev/null | sed 's/.*=//')
  if [[ -n "$last" ]]; then
    echo -e "Last played  @${B}$(date -d "@${last}" '+%Y-%m-%d %H:%M:%S')${N}"
  fi

  local first
  first=$(mpc sticker "$FILE" get firstPlayed 2>/dev/null | sed 's/.*=//')
  if [[ -n "$first" ]]; then
    echo -e "First played @${C}$(date -d "@${first}" '+%Y-%m-%d %H:%M:%S')${N}"
  fi

  echo
}

cmd=${1-}
arg=${2-}

case "$cmd" in
  ''|s|status)
    rating=$(mpc sticker "$FILE" get rating 2>/dev/null | sed 's/.*=//')
    if [[ -n "$rating" ]]; then
      print_status $(awk -v r="$rating" 'BEGIN{v = r / 2; if (v == int(v)) printf "%d", v; else printf "%.1f", v}')
    else
      print_status 0
    fi
    ;;
  r|rate)
    old=$(mpc sticker "$FILE" get rating 2>/dev/null | sed 's/.*=//')
    if [[ -n "$old" ]]; then
      state=$(awk -v o="$old" 'BEGIN{v = o / 2; if (v == int(v)) printf "%d", v; else printf "%.1f", v}')
    else
      state=0
    fi

    if [[ -z "$arg" ]]; then
      if [[ -n "$old" && "$old" -gt 0 ]]; then
        mpc sticker "$FILE" delete rating
        new=0
      else
        mpc sticker "$FILE" set rating 10
        new=10
      fi
    elif awk -v a="$arg" 'BEGIN{if (a == 0) exit 0; exit 1}'; then
      mpc sticker "$FILE" delete rating
      new=0
    elif awk -v a="$arg" 'BEGIN{if (a > 5) exit 0; exit 1}'; then
      mpc sticker "$FILE" set rating 10
      new=10
    else
      new=$(awk -v a="$arg" 'BEGIN{printf "%d", a * 2 + 0.5}')
      mpc sticker "$FILE" set rating "$new"
    fi

    print_status $(awk -v n="$new" 'BEGIN{v = n / 2; if (v == int(v)) printf "%d", v; else printf "%.1f", v}') "$state"
    ;;
  *)
    echo "Usage: mps [s|status|r|rate [N]]"
    exit 1
    ;;
esac

