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
# Create a new tmux window configured for an AWS profile
#
# Arguments:
#   $1 - AWS profile name
# Side effects:
#   Creates a new tmux window, sets its name based on AWS account ID and region,
#   sets its color based on AWS environment, and selects the new window.
_tmux_window() {
	local aws_profile="$1"

	local aws_environment
	aws_environment="$(_aws_get_option "$aws_profile" "environment" "none")"

	local window_color
	window_color="$(_tmux_get_window_color "$aws_environment")"

	local window_id
	window_id="$(tmux display -p '#{window_id}')"

	tmux set-window-option -t "$window_id" @AWS_PROFILE "$aws_profile"
	# Windows Styles
	tmux set-window-option -F -t "$window_id" window-status-style "fg=#{${window_color}},bg=#{@thm_bg},nobold"
	tmux set-window-option -F -t "$window_id" window-status-current-style "fg=#{@thm_bg},bg=#{${window_color}},nobold"
	tmux set-window-option -F -t "$window_id" window-status-bell-style "fg=#{${window_color}},bg=#{@thm_bg}"
	tmux set-window-option -F -t "$window_id" window-status-activity-style "fg=#{${window_color}},bg=#{@thm_bg},italics"

	# Window Formats
	tmux set-window-option -t "$window_id" window-status-format " #I:   #W #F "
	tmux set-window-option -t "$window_id" window-status-current-format " #I:   #W #F "
}

main() {
	# Command router
	case "${1:-}" in
	--profile)
		shift
		_tmux_window "$1"
		;;
	esac
}

main "$@"
