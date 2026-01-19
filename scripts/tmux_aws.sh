#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

_tmux_aws_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux_core.sh
source "$_tmux_aws_source_dir/tmux_core.sh"

# Get tmux color based on AWS environment
#
# Arguments:
#   $1 - AWS environment name (e.g., "dev", "stage", "prod")
# Outputs:
#   Tmux color variable name (e.g., "@thm_yellow")
_tmux_get_color() {
	local aws_environment="$1"

	# Convert to lowercase for case-insensitive matching
	local color="@thm_rosewater"
	# Partial match against type
	case "$aws_environment" in
	*dev*)
		color="@thm_yellow"
		;;
	*stage*)
		color="@thm_peach"
		;;
	*prod*)
		color="@thm_red"
		;;
	esac

	echo "$color"
}

# Execute an interactive shell in a tmux window configured for an AWS profile
#
# Arguments:
#   --profile - AWS profile name
#   --window - (Optional) Target window in format "session:index" (e.g., "mysession:0")
#              If not provided, defaults to the current window
# Side effects:
#   Sets window styling and variables for the specified or current window
#   based on the AWS profile's environment configuration, then launches an interactive shell.
_tmux_exec_window() {
	local aws_profile=""
	local aws_window=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		--window)
			shift
			aws_window="$1"
			shift
			;;
		*)
			shift
			;;
		esac
	done

	local aws_environment
	aws_environment="$(_aws_get_option "$aws_profile" "environment" "none")"

	local window_color
	window_color="$(_tmux_get_color "$aws_environment")"

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

	# We can now launch the interactive shell
	$SHELL -i
}

# Create a new tmux window with AWS profile configuration
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Creates a new tmux window named with the AWS account ID and region.
#   The window is launched via aws-vault exec and automatically styled for the profile.
_tmux_new_window() {
	local aws_profile=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		*)
			shift
			;;
		esac
	done

	local aws_account_id
	aws_account_id="$(_aws_get_option "$aws_profile" "sso_account_id" "none")"

	local aws_region
	aws_region="$(_aws_get_option "$aws_profile" "sso_region" "none")"

	tmux new-window -n "$aws_account_id-$aws_region" \
		"aws-vault exec $aws_profile -- $_tmux_aws_source_dir/tmux_aws.sh exec-window --profile $aws_profile"
}

# Execute an interactive shell in a tmux session configured for an AWS profile
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Sets session-level environment variables for AWS credentials, applies session styling
#   based on the AWS profile's environment configuration, then launches an interactive shell.
#   All future windows/panes created in this session will inherit the AWS credentials.
_tmux_exec_session() {
	local aws_profile=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		*)
			shift
			;;
		esac
	done

	local session_name
	session_name="$(tmux display -p '#{session_name}')"

	# Set session environment variables from current process environment
	# These will be inherited by all windows/panes in the session
	[[ -n "$AWS_VAULT" ]] && tmux set-environment -t "$session_name" AWS_VAULT "$AWS_VAULT"
	[[ -n "$AWS_REGION" ]] && tmux set-environment -t "$session_name" AWS_REGION "$AWS_REGION"
	[[ -n "$AWS_DEFAULT_REGION" ]] && tmux set-environment -t "$session_name" AWS_DEFAULT_REGION "$AWS_DEFAULT_REGION"
	[[ -n "$AWS_ACCESS_KEY_ID" ]] && tmux set-environment -t "$session_name" AWS_ACCESS_KEY_ID "$AWS_ACCESS_KEY_ID"
	[[ -n "$AWS_SECRET_ACCESS_KEY" ]] && tmux set-environment -t "$session_name" AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY"
	[[ -n "$AWS_SESSION_TOKEN" ]] && tmux set-environment -t "$session_name" AWS_SESSION_TOKEN "$AWS_SESSION_TOKEN"
	[[ -n "$AWS_CREDENTIAL_EXPIRATION" ]] && tmux set-environment -t "$session_name" AWS_CREDENTIAL_EXPIRATION "$AWS_CREDENTIAL_EXPIRATION"

	# Set session option for status line integration
	tmux set-option -t "$session_name" @AWS_PROFILE "$aws_profile"

	# Apply session styling based on AWS environment
	local aws_environment
	aws_environment="$(_aws_get_option "$aws_profile" "environment" "none")"

	local session_color
	session_color="$(_tmux_get_color "$aws_environment")"

	# Session Styles
	tmux set-option -F -t "$session_name" session-status-style "fg=#{${session_color}},bg=#{@thm_bg}"
	tmux set-option -F -t "$session_name" session-status-current-style "fg=#{@thm_bg},bg=#{${session_color}}"

	# Launch the interactive shell which will inherit all session environment variables
	$SHELL -i
}

# Create a new tmux session with AWS profile configuration
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Creates a new tmux session named with the AWS account ID and region.
#   The session is launched via aws-vault exec and all windows/panes will
#   inherit AWS credentials at the session level.
_tmux_new_session() {
	local aws_profile=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		*)
			shift
			;;
		esac
	done

	local aws_account_id
	aws_account_id="$(_aws_get_option "$aws_profile" "sso_account_id" "none")"

	local aws_region
	aws_region="$(_aws_get_option "$aws_profile" "sso_region" "none")"

	local session_name="$aws_account_id-$aws_region"
	# Check if session already exists
	if tmux has-session -t "$session_name" 2>/dev/null; then
		# Session exists, switch to it
		tmux switch-client -t "$session_name" 2>/dev/null || tmux attach -t "$session_name"
		return
	fi

	# Create new detached session with aws-vault exec wrapping
	tmux new-session -d -s "$session_name" \
		"aws-vault exec $aws_profile -- $_tmux_aws_source_dir/tmux_aws.sh exec-session --profile $aws_profile"

	# Attach or switch to the new session
	tmux switch-client -t "$session_name" 2>/dev/null || tmux attach -t "$session_name"
}

# Main command router
#
# Arguments:
#   $1 - Command name (new-window, exec-window, new-session, exec-session)
#   $@ - Command-specific arguments (passed to the respective function)
# Commands:
#   new-window   - Create a new tmux window with AWS profile configuration
#   exec-window  - Execute an interactive shell in a styled tmux window
#   new-session  - Create a new tmux session with AWS profile configuration
#   exec-session - Execute an interactive shell in a styled tmux session
main() {
	local command="${1:-}"
	shift || true

	case "$command" in
	new-window)
		_tmux_new_window "$@"
		;;
	exec-window)
		_tmux_exec_window "$@"
		;;
	new-session)
		_tmux_new_session "$@"
		;;
	exec-session)
		_tmux_exec_session "$@"
		;;
	esac
}

main "$@"
