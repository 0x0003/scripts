#!/usr/bin/env bash

NAME=$(basename $(pwd))
EXISTS=$(tmux has-session -t $NAME)

if [[ -n $TMUX ]] && [[ -z $EXISTS ]]; then
  tmux new -s $NAME -d && tmux switch-client -t $NAME
elif [[ -n $TMUX ]]; then
  tmux switch-client -t $NAME
else
  tmux new-session -As $NAME
fi

