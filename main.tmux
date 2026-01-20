#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

_tmux_aws_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tmux_core.sh
source "$_tmux_aws_root/scripts/tmux_core.sh"

# Interactive AWS profile selection (requires aws-fzf)
# Check if both aws-cli and aws-fzf are available
if command -v aws &>/dev/null && aws fzf --help &>/dev/null 2>&1; then
    # Get fzf prefix key (respect tmux-fzf's setting if present, else default 'f')
    _fzf_prefix=$(_tmux_get_option "@fzf-prefix-key")
    _fzf_prefix=${_fzf_prefix:-'f'}

    # Create/ensure fzf-menu key table exists
    tmux bind "$_fzf_prefix" switch-client -T fzf-menu

    # Get AWS key within fzf-menu
    _fzf_aws_key=$(_tmux_get_option "@fzf-aws-key")
    _fzf_aws_key=${_fzf_aws_key:-'a'}

    # Always bind to fzf-menu table
    tmux bind -T fzf-menu "$_fzf_aws_key" run-shell "$_tmux_aws_root/scripts/tmux_aws_fzf.sh"
fi
