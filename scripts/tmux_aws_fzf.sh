#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DEBUG:-}" ]] || set -x

_tmux_aws_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "$_tmux_aws_source_dir/tmux_core.sh" ]] || {
	echo "tmux-aws: missing tmux_core.sh" >&2
	exit 1
}

# shellcheck source=tmux_core.sh
source "$_tmux_aws_source_dir/tmux_core.sh"

# Check aws-fzf availability
if ! command -v aws &>/dev/null; then
	tmux display-message "tmux-aws: aws-cli is not installed"
	exit 1
fi

if ! aws fzf --help &>/dev/null 2>&1; then
	tmux display-message "tmux-aws: aws-fzf plugin is not installed"
	exit 1
fi

# Launch aws-fzf with tmux-aws keybindings
# alt-c: Create new window with selected profile
# alt-C: Create new session with selected profile
# alt-w: Authenticate current window with selected profile
# alt-s: Authenticate current session with selected profile
aws fzf --tmux \
	--bind "alt-c:become($_tmux_aws_source_dir/tmux_aws.sh new-window --profile {1})" \
	--bind "alt-C:become($_tmux_aws_source_dir/tmux_aws.sh new-session --profile {1})" \
	--bind "alt-w:become($_tmux_aws_source_dir/tmux_aws.sh auth-window --profile {1})" \
	--bind "alt-s:become($_tmux_aws_source_dir/tmux_aws.sh auth-session --profile {1})" \
	sso profile list >/dev/null || true
