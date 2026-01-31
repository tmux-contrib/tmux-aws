#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

_tmux_aws_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tmux_core.sh
source "$_tmux_aws_root/scripts/tmux_core.sh"

# Define interpolation patterns for dynamic updates
# Session-level patterns (for status-left/status-right)
aws_credential_ttl_session_interpolation="#($_tmux_aws_root/scripts/tmux_aws.sh get-session ttl)"
aws_profile_session_interpolation="#($_tmux_aws_root/scripts/tmux_aws.sh get-session profile)"

# Window-level patterns (for window-status-format)
aws_credential_ttl_window_interpolation="#($_tmux_aws_root/scripts/tmux_aws.sh get-window ttl)"
aws_profile_window_interpolation="#($_tmux_aws_root/scripts/tmux_aws.sh get-window profile)"

aws_credential_ttl_pattern="#{aws_credential_ttl}"
aws_profile_pattern="#{aws_profile}"

# Set a tmux option with proper quoting for nested commands
#
# Arguments:
#   $1 - The name of the tmux option to set
#   $2 - The value to set
_tmux_set_option() {
    local option="$1"
    local value="$2"

    tmux set-option -g "$option" "$value"
}

# Interpolate AWS patterns for session-level options
#
# Replaces #{aws_credential_ttl} and #{aws_profile} patterns
# with tmux command strings that retrieve session-level values.
#
# Arguments:
#   $1 - The content string containing patterns
# Outputs:
#   The content with patterns replaced by session-level commands
_tmux_interpolate_session() {
    local content="$1"

    # Use sed for reliable pattern replacement (#{} has special meaning in bash)
    content=$(echo "$content" | sed "s|#{aws_credential_ttl}|$aws_credential_ttl_session_interpolation|g")
    content=$(echo "$content" | sed "s|#{aws_profile}|$aws_profile_session_interpolation|g")

    echo "$content"
}

# Interpolate AWS patterns for window-level options
#
# Replaces #{aws_credential_ttl} and #{aws_profile} patterns
# with tmux command strings that retrieve window-level values.
#
# Arguments:
#   $1 - The content string containing patterns
# Outputs:
#   The content with patterns replaced by window-level commands
_tmux_interpolate_window() {
    local content="$1"

    # Use sed for reliable pattern replacement (#{} has special meaning in bash)
    content=$(echo "$content" | sed "s|#{aws_credential_ttl}|$aws_credential_ttl_window_interpolation|g")
    content=$(echo "$content" | sed "s|#{aws_profile}|$aws_profile_window_interpolation|g")

    echo "$content"
}

# Update a tmux option by interpolating AWS patterns (session-level)
#
# Arguments:
#   $1 - The name of the tmux option to update
_tmux_update_session_option() {
    local option="$1"
    local option_value

    option_value="$(_tmux_get_option "$option")"
    option_value="$(_tmux_interpolate_session "$option_value")"

    _tmux_set_option "$option" "$option_value"
}

# Update a tmux option by interpolating AWS patterns (window-level)
#
# Arguments:
#   $1 - The name of the tmux option to update
_tmux_update_window_option() {
    local option="$1"
    local option_value

    option_value="$(_tmux_get_option "$option")"
    option_value="$(_tmux_interpolate_window "$option_value")"

    _tmux_set_option "$option" "$option_value"
}

# Setup interactive AWS profile selection using aws-fzf
#
# Prerequisites:
#   - aws-cli must be installed
#   - aws-fzf plugin must be available
# Side effects:
#   - Creates fzf-menu key table if not exists
#   - Binds keybindings for AWS profile selection
_tmux_setup_fzf() {
    # Check if both aws-cli and aws-fzf are available
    if ! command -v aws &>/dev/null || ! aws fzf --help &>/dev/null 2>&1; then
        return 0  # Silently skip if dependencies not available
    fi

    # Get fzf prefix key (respect tmux-fzf's setting if present, else default 'f')
    local fzf_prefix
    fzf_prefix=$(_tmux_get_option "@fzf-prefix-key")
    fzf_prefix=${fzf_prefix:-'f'}

    # Create/ensure fzf-menu key table exists
    tmux bind "$fzf_prefix" switch-client -T fzf-menu

    # Get AWS key within fzf-menu
    local fzf_aws_key
    fzf_aws_key=$(_tmux_get_option "@fzf-aws-key")
    fzf_aws_key=${fzf_aws_key:-'a'}

    # Bind to fzf-menu table
    tmux bind -T fzf-menu "$fzf_aws_key" run-shell "$_tmux_aws_root/scripts/tmux_aws_fzf.sh"
}

# Main entry point for tmux-aws plugin
main() {
    # Interpolate session-level patterns in status bar options
    _tmux_update_session_option "status-right"
    _tmux_update_session_option "status-left"

    # Interpolate window-level patterns in window status options
    _tmux_update_window_option "window-status-format"
    _tmux_update_window_option "window-status-current-format"

    # Setup aws-fzf integration (if available)
    _tmux_setup_fzf
}

main
