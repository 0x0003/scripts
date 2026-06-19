#!/usr/bin/env bash

selection=$(
  sesh list --icons --hide-duplicates | \
    fzf-tmux -p 55%,63% --delimiter=' ' \
    --padding 5%,4 --separator="" --scrollbar="" \
    --ansi --pointer=" " --no-bold --layout=reverse \
    --color=gutter:-1,fg:-1,fg+:7,bg:-1,bg+:8 \
    --color=hl:4,hl+:6,info:2,marker:1 \
    --color=prompt:3,spinner:-1,pointer:7,header:8 \
    --color=border:8,label:-1,query:-1 \
    --no-sort --border="none" --prompt '› ' \
    --header '^a·all ^t·tmux ^g·conf ^x·zoxide ^r·kill ^f·find' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(› )+reload(sesh list -i)' \
    --bind 'ctrl-t:change-prompt( )+reload(sesh list -ti)' \
    --bind 'ctrl-g:change-prompt( )+reload(sesh list -ci)' \
    --bind 'ctrl-x:change-prompt( )+reload(sesh list -zi)' \
    --bind 'ctrl-f:change-prompt( )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-r:execute(tmux kill-session -t {2})+reload(sesh list -i)'
)

[[ -z "$selection" ]] && exit 0
sesh connect "$selection"

