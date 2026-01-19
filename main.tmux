#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

_tmux_aws_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tmux_core.sh
source "$_tmux_aws_root/scripts/tmux_core.sh"

# Interactive AWS profile selection (requires aws-fzf)
# Check if both aws-cli and aws-fzf are available
if command -v aws &>/dev/null && aws fzf --help &>/dev/null 2>&1; then
    # Check if tmux-fzf is installed for unified fzf-menu
    _has_tmux_fzf=$(_tmux_get_option "@fzf-prefix-key")

    if [ -n "$_has_tmux_fzf" ]; then
        # Integrate with fzf-menu for unified experience
        _fzf_aws_key=$(_tmux_get_option "@fzf-aws-key")
        _fzf_aws_key=${_fzf_aws_key:-'a'}
        tmux bind -T fzf-menu "$_fzf_aws_key" run-shell "$_tmux_aws_root/scripts/tmux_aws_fzf.sh"
    else
        # Create standalone binding
        _aws_prefix=$(_tmux_get_option "@aws-prefix-key")
        _aws_prefix=${_aws_prefix:-'A'}
        tmux bind "$_aws_prefix" run-shell "$_tmux_aws_root/scripts/tmux_aws_fzf.sh"
    fi
fi
