#!/usr/bin/env bash

_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_source_dir/tmux_core.sh"

# Check aws-fzf availability
if ! command -v aws &>/dev/null; then
    tmux display-message "Error: aws-cli is not installed"
    exit 1
fi

if ! aws fzf --help &>/dev/null 2>&1; then
    tmux display-message "Error: aws-fzf is not installed"
    exit 1
fi

# Launch aws-fzf with tmux-aws keybindings
aws fzf --tmux \
    --bind "alt-n:become($_source_dir/tmux_aws.sh new-window --profile {1})" \
    --bind "alt-N:become($_source_dir/tmux_aws.sh new-session --profile {1})" \
    sso profile list
