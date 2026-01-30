#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

_tmux_aws_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux_core.sh
source "$_tmux_aws_source_dir/tmux_core.sh"

# Get configured vault executable path
_tmux_get_aws_vault_path() {
	local aws_vault_path
	aws_vault_path="$(tmux show-option -gqv @tmux-aws-vault-path)"
	aws_vault_path="${aws_vault_path:-aws-vault}"

	# Expand tilde to $HOME if path starts with ~/
	aws_vault_path="${aws_vault_path/#\~/$HOME}"

	echo "$aws_vault_path"
}

# Get environment variable regex pattern
_tmux_get_aws_env_regex() {
	local aws_env_regex
	aws_env_regex="$(tmux show-option -gqv @tmux-aws-env-regex)"
	echo "${aws_env_regex:-^AWS_}"
}


# Execute an interactive shell in a tmux window configured for an AWS profile
#
# Arguments:
#   --profile - AWS profile name
#   --window - (Optional) Target window in format "session:index" (e.g., "mysession:0")
#              If not provided, defaults to the current window
# Side effects:
#   Sets window variable for the specified or current window, then launches an interactive shell.
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


	if [[ -z "$aws_window" ]]; then
		# Auto-detect current window (backward compatible)
		aws_window="$(tmux display -p '#{session_name}:#{window_index}')"
	fi

	# Set window variable for user consumption
	tmux set-window-option -t "$aws_window" @aws_profile "$aws_profile"

	"$SHELL" -i
}

# Authenticate current tmux window with AWS profile configuration
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Applies AWS credentials to the current window via aws-vault exec.
_tmux_auth_window() {
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

	# Get configured vault executable
	local aws_vault_path
	aws_vault_path="$(_tmux_get_aws_vault_path)"

	# Check if vault executable exists
	if ! command -v "$aws_vault_path" &>/dev/null; then
		echo "ERROR: $aws_vault_path not found in PATH" >&2
		echo "Configure with: set -g @tmux-aws-vault-path '<path>'" >&2
		return 1
	fi

	# Use aws-vault-compatible interface: exec <profile> -- <command>
	"$aws_vault_path" exec "$aws_profile" -- \
		"$_tmux_aws_source_dir/tmux_aws.sh" exec-window --profile "$aws_profile"
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
		"$_tmux_aws_source_dir/tmux_aws.sh auth-window --profile $aws_profile"
}

# Execute an interactive shell in a tmux session configured for an AWS profile
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Sets session-level environment variables for AWS credentials and session variable,
#   then launches an interactive shell.
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

	# Get environment variable regex from configuration
	local aws_env_regex
	aws_env_regex="$(_tmux_get_aws_env_regex)"

	# Dynamically set environment variables matching the regex pattern
	# This supports AWS_*, TF_*, HSDK_*, or any custom pattern
	# These will be inherited by all windows/panes in the session
	while IFS='=' read -r -d '' name value; do
		if [[ "$name" =~ $aws_env_regex ]]; then
			tmux set-environment -t "$session_name" "$name" "$value"
		fi
	done < <(env -0)

	# Set session variable for user consumption
	tmux set-option -t "$session_name" @aws_profile "$aws_profile"


	"$SHELL" -i
}

# Authenticate current tmux session with AWS profile configuration
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Applies AWS credentials to the current session via aws-vault exec.
#   The session is wrapped with aws-vault and all windows/panes will
#   inherit AWS credentials at the session level.
_tmux_auth_session() {
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

	# Get configured vault executable
	local aws_vault_path
	aws_vault_path="$(_tmux_get_aws_vault_path)"

	# Check if vault executable exists
	if ! command -v "$aws_vault_path" &>/dev/null; then
		echo "ERROR: $aws_vault_path not found in PATH" >&2
		echo "Configure with: set -g @tmux-aws-vault-path '<path>'" >&2
		return 1
	fi

	# Use aws-vault-compatible interface: exec <profile> -- <command>
	"$aws_vault_path" exec "$aws_profile" -- \
		"$_tmux_aws_source_dir/tmux_aws.sh" exec-session --profile "$aws_profile"
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
		"$_tmux_aws_source_dir/tmux_aws.sh auth-session --profile $aws_profile"

	# Attach or switch to the new session
	tmux switch-client -t "$session_name" 2>/dev/null || tmux attach -t "$session_name"
}

# Main command router
#
# Arguments:
#   $1 - Command name (new-window, exec-window, new-session, exec-session, auth-session, auth-window)
#   $@ - Command-specific arguments (passed to the respective function)
# Commands:
#   new-window   - Create a new tmux window with AWS profile configuration
#   exec-window  - Execute an interactive shell in a styled tmux window
#   new-session  - Create a new tmux session with AWS profile configuration
#   exec-session - Execute an interactive shell in a styled tmux session
#   auth-session - Authenticate current tmux session with AWS profile configuration
#   auth-window  - Authenticate current tmux window with AWS profile configuration
main() {
	local command="${1:-}"
	shift || true

	case "$command" in
	exec-window)
		_tmux_exec_window "$@"
		;;
	auth-window)
		_tmux_auth_window "$@"
		;;
	new-window)
		_tmux_new_window "$@"
		;;
	exec-session)
		_tmux_exec_session "$@"
		;;
	auth-session)
		_tmux_auth_session "$@"
		;;
	new-session)
		_tmux_new_session "$@"
		;;
	esac
}

main "$@"
