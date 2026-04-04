#!/usr/bin/env bash
printf "Installing \033[36mjuke.sh\033[0m as \033[33m%s\033[0m.\n" "$USER"
mkdir -p "$HOME/.local/bin"
cp juke.sh "$HOME/.local/bin/juke.sh"
chmod +x "$HOME/.local/bin/juke.sh"
