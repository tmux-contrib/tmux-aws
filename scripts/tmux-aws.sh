#!/usr/bin/env bash

_tmux_aws_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$_tmux_aws_source_dir/core.sh"

_tmux_get_window_color() {
	local aws_environment="$1"

	# Convert to lowercase for case-insensitive matching
	local window_color="@thm_rosewater"
	# Partial match against type
	case "$aws_environment" in
	*dev*)
		window_color="@thm_yellow"
		;;
	*stage*)
		window_color="@thm_peach"
		;;
	*prod*)
		window_color="@thm_red"
		;;
	esac

	echo "$window_color"
}

_tmux_get_window_name() {
	local aws_profile="$1"

	local aws_region
	aws_region="$(_aws_get_option "$aws_profile" "region" "us-east-1")"

	local aws_account_id
	aws_account_id="$(_aws_get_option "$aws_profile" "sso_account_id" "none")"

	echo "$aws_account_id-$aws_region"
}

_tmux_new_window() {
	local aws_profile="$1"

	local aws_environment
	aws_environment="$(_aws_get_option "$aws_profile" "environment" "none")"

	local window_color
	window_color="$(_tmux_get_window_color "$aws_environment")"

	local window_name
	window_name="$(_tmux_get_window_name "$aws_profile")"

	local window_id
	window_id="$(tmux new-window -d -P -F '#{window_id}' -n "$window_name")"

	tmux set-window-option -t "$window_id" @AWS_PROFILE "$aws_profile"
	# Style active window with environment-specific color, text, and AWS icon
	tmux set-window-option -t "$window_id" window-status-current-format "#[fg=#{@thm_bg},bg=#{${window_color}}] #I:   #W #F "
	# Style inactive window with environment-specific color and AWS icon
	tmux set-window-option -t "$window_id" window-status-format "#[fg=#{${window_color}},bg=#{@thm_bg}] #I:   #W #F "
	# Select the newly created window
	tmux select-window -t "$window_id"
}

_tmux_new_window "$@"

main() {
	# Command router
	case "${1:-}" in
	new-window)
		shift
		_tmux_new_window "$1"
		;;
	esac
}

main "$@"
