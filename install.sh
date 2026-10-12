#!/bin/sh
set -e

bin="$HOME/.local/bin"
mkdir -p "$bin"
swiftc -O "$(dirname "$0")/touch-prompt.swift" -o "$bin/touch-prompt"
install -m 755 "$(dirname "$0")/git-ssh-sign" "$bin/git-ssh-sign"
git config --global gpg.ssh.program "$bin/git-ssh-sign"
echo "Installed. git now signs through $bin/git-ssh-sign"
