#!/usr/bin/env bash

_tmux_aws_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$_tmux_aws_source_dir/core.sh"

# Get tmux window color based on AWS environment
#
# Arguments:
#   $1 - AWS environment name (e.g., "dev", "stage", "prod")
# Outputs:
#   Tmux color variable name (e.g., "@thm_yellow")
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

# Create a new tmux window configured for an AWS profile
#
# Arguments:
#   $1 - AWS profile name
#   $2 - (Optional) Target window in format "session:index" (e.g., "mysession:0")
#        If not provided, defaults to the current window
# Side effects:
#   Sets window styling and variables for the specified or current window
#   based on the AWS profile's environment configuration.
_tmux_window() {
	local aws_profile="$1"
	local aws_window="${2:-}"

	local aws_environment
	aws_environment="$(_aws_get_option "$aws_profile" "environment" "none")"

	local window_color
	window_color="$(_tmux_get_window_color "$aws_environment")"

	if [[ -z "$aws_window" ]]; then
		# Auto-detect current window (backward compatible)
		aws_window="$(tmux display -p '#{session_name}:#{window_index}')"
	fi

	tmux set-window-option -t "$aws_window" @AWS_PROFILE "$aws_profile"
	# Windows Styles
	tmux set-window-option -F -t "$aws_window" window-status-style "fg=#{${window_color}},bg=#{@thm_bg},nobold"
	tmux set-window-option -F -t "$aws_window" window-status-current-style "fg=#{@thm_bg},bg=#{${window_color}},nobold"
	tmux set-window-option -F -t "$aws_window" window-status-bell-style "fg=#{${window_color}},bg=#{@thm_bg}"
	tmux set-window-option -F -t "$aws_window" window-status-activity-style "fg=#{${window_color}},bg=#{@thm_bg},italics"

	# Window Formats
	tmux set-window-option -t "$aws_window" window-status-format " #I:   #W #F "
	tmux set-window-option -t "$aws_window" window-status-current-format " #I:   #W #F "
}

main() {
	# Command router
	local aws_profile=""
	local aws_window=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		--target)
			shift
			aws_window="$1"
			shift
			;;
		*)
			shift
			;;
		esac
	done

	if [[ -n "$aws_profile" ]]; then
		_tmux_window "$aws_profile" "$aws_window"
	fi
}

main "$@"
