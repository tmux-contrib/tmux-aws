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
# alt-c: Create new window with selected profile
# alt-C: Create new session with selected profile
# alt-w: Authenticate current window with selected profile
# alt-s: Authenticate current session with selected profile
aws fzf --tmux \
	--bind "alt-c:become($_source_dir/tmux_aws.sh new-window --profile {1})" \
	--bind "alt-C:become($_source_dir/tmux_aws.sh new-session --profile {1})" \
	--bind "alt-w:become($_source_dir/tmux_aws.sh auth-window --profile {1})" \
	--bind "alt-s:become($_source_dir/tmux_aws.sh auth-session --profile {1})" \
	sso profile list >/dev/null || true
