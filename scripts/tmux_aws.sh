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

# Get configured vault executable path
#
# Reads @aws-vault-path from tmux global options.
# Falls back to "aws-vault" if unset. Expands leading ~/ to $HOME.
#
# Outputs:
#   Resolved path to the vault executable
_tmux_get_aws_vault_path() {
	local aws_vault_path
	aws_vault_path="$(_tmux_get_option "@aws-vault-path" "aws-vault")"

	# Expand tilde to $HOME if path starts with ~/
	aws_vault_path="${aws_vault_path/#\~/$HOME}"

	echo "$aws_vault_path"
}

# Get environment variable regex pattern
#
# Reads @aws-env-regex from tmux global options.
# Falls back to "^AWS_" if unset.
#
# Outputs:
#   Regex pattern for matching environment variables to propagate
_tmux_get_aws_env_regex() {
	_tmux_get_option "@aws-env-regex" "^AWS_"
}

# Display an authenticated message with available details
#
# Arguments:
#   $1 - scope ("window" or "session")
#   $2 - AWS profile name
#   $3 - AWS account ID (may be empty)
#   $4 - AWS region (may be empty)
#   $5 - credential TTL (may be empty)
_tmux_display_message() {
	local scope="$1"
	local aws_profile="$2"
	local aws_account_id="$3"
	local aws_region="$4"
	local aws_ttl="$5"

	local message="AWS [$scope]: $aws_profile"
	local details=""

	if [[ -n "$aws_account_id" ]]; then
		details="$aws_account_id"
	fi

	if [[ -n "$aws_region" ]]; then
		details="${details:+$details · }$aws_region"
	fi

	if [[ -n "$aws_ttl" ]]; then
		details="${details:+$details · }$aws_ttl"
	fi

	if [[ -n "$details" ]]; then
		message="$message  $details"
	fi

	tmux display-message "$message"
}

# Execute an interactive shell in a tmux window configured for an AWS profile
#
# Arguments:
#   --profile - AWS profile name
#   --window  - (Optional) Target window in format "session:index" (e.g., "mysession:0")
#               If not provided, defaults to the current window
# Side effects:
#   Sets window variables (@aws-profile, @aws-credential-expiration, @aws-credential-ttl,
#   @aws-account-id, @aws-region) for the specified or current window, then launches an
#   interactive shell. Displays an authenticated summary on shell exit.
_tmux_exec_window() {
	local aws_profile=""
	local aws_window=""
	local start_shell="false"

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
		--start-shell)
			start_shell="true"
			shift
			;;
		*)
			echo "tmux-aws: exec-window: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	if [[ -z "$aws_window" ]]; then
		# Auto-detect current window (backward compatible)
		aws_window="$(tmux display -p '#{session_name}:#{window_index}')"
	fi

	# Set window variables for user consumption
	_tmux_set_window_option "$aws_window" "@aws-profile" "$aws_profile"

	# Set credential expiration variables
	if [[ -n "${AWS_CREDENTIAL_EXPIRATION:-}" ]]; then
		# Store raw ISO8601 timestamp for dynamic calculation
		_tmux_set_window_option "$aws_window" "@aws-credential-expiration" "$AWS_CREDENTIAL_EXPIRATION"

		# Also calculate initial formatted TTL (for backwards compatibility)
		local duration
		duration="$(_time_get_duration "$AWS_CREDENTIAL_EXPIRATION")"

		if [[ -n "$duration" ]]; then
			local duration_ttl
			duration_ttl="$(_time_format_duration "$duration")"

			_tmux_set_window_option "$aws_window" "@aws-credential-ttl" "$duration_ttl"
		fi
	fi

	# Set AWS account ID if available
	local aws_account_id="${AWS_ACCOUNT_ID:-}"
	if [[ -n "$aws_account_id" ]]; then
		_tmux_set_window_option "$aws_window" "@aws-account-id" "$aws_account_id"
	fi

	# Set AWS region if available
	local aws_region="${AWS_REGION:-}"
	if [[ -n "$aws_region" ]]; then
		_tmux_set_window_option "$aws_window" "@aws-region" "$aws_region"
	fi

	# Display authenticated message with available details
	local aws_ttl=""
	if [[ -n "${AWS_CREDENTIAL_EXPIRATION:-}" ]]; then
		aws_ttl="$(_tmux_get_window_option "$aws_window" "@aws-credential-ttl")"
	fi

	_tmux_display_message "window" "$aws_profile" "$aws_account_id" "$aws_region" "$aws_ttl"

	if [[ "$start_shell" == "true" ]]; then
		"$SHELL" -i
	fi
}

# Authenticate current tmux window with AWS profile configuration
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Applies AWS credentials to the current window via aws-vault exec.
_tmux_auth_window() {
	local aws_profile=""
	local start_shell=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		--start-shell)
			start_shell="--start-shell"
			shift
			;;
		*)
			echo "tmux-aws: auth-window: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	# Block re-authentication if already inside an aws-vault session
	if [[ -n "${AWS_VAULT:-}" ]]; then
		tmux display-message "AWS: already authenticated as '$AWS_VAULT' (open a new window for a different profile)"
		return 1
	fi

	# Get configured vault executable
	local aws_vault_path
	aws_vault_path="$(_tmux_get_aws_vault_path)"

	# Check if vault executable exists
	if ! command -v "$aws_vault_path" &>/dev/null; then
		tmux display-message "AWS: vault command not found ($aws_vault_path)"
		return 1
	fi

	tmux display-message "AWS: authenticating window as '$aws_profile'..."

	# Use aws-vault-compatible interface: exec <profile> -- <command>
	if ! "$aws_vault_path" exec "$aws_profile" -- \
		"$_tmux_aws_source_dir/tmux_aws.sh" exec-window --profile "$aws_profile" ${start_shell:+"$start_shell"}; then
		tmux display-message "AWS: authentication failed for '$aws_profile'"
		return 1
	fi
}

# Create a new tmux window with AWS profile configuration
#
# Arguments:
#   --profile - AWS profile name
# Side effects:
#   Creates a new tmux window named "<account_id>-<region>" and delegates to auth-window.
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
			echo "tmux-aws: new-window: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	local aws_account_id
	aws_account_id="$(_aws_get_option "$aws_profile" "sso_account_id" "")"

	local aws_region
	aws_region="$(_aws_get_option "$aws_profile" "sso_region" "")"

	if [[ -z "$aws_account_id" || -z "$aws_region" ]]; then
		tmux display-message "AWS: missing account or region for '$aws_profile'"
		return 1
	fi

	if [[ ! "$aws_account_id" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$aws_region" =~ ^[a-zA-Z0-9._-]+$ ]]; then
		tmux display-message "AWS: invalid account or region for '$aws_profile'"
		return 1
	fi

	tmux new-window -n "$aws_account_id-$aws_region" \
		"$_tmux_aws_source_dir/tmux_aws.sh" auth-window --profile "$aws_profile" --start-shell
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
	local start_shell="false"

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		--start-shell)
			start_shell="true"
			shift
			;;
		*)
			echo "tmux-aws: exec-session: unknown argument: $1" >&2
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

	# Set session variables for user consumption
	_tmux_set_session_option "$session_name" "@aws-profile" "$aws_profile"

	# Set credential expiration variables
	if [[ -n "${AWS_CREDENTIAL_EXPIRATION:-}" ]]; then
		# Store raw ISO8601 timestamp for dynamic calculation
		_tmux_set_session_option "$session_name" "@aws-credential-expiration" "$AWS_CREDENTIAL_EXPIRATION"

		# Also calculate initial formatted TTL (for backwards compatibility)
		local duration
		duration="$(_time_get_duration "$AWS_CREDENTIAL_EXPIRATION")"

		if [[ -n "$duration" ]]; then
			local duration_ttl
			duration_ttl="$(_time_format_duration "$duration")"

			_tmux_set_session_option "$session_name" "@aws-credential-ttl" "$duration_ttl"
		fi
	fi

	# Set AWS account ID if available
	local aws_account_id="${AWS_ACCOUNT_ID:-}"
	if [[ -n "$aws_account_id" ]]; then
		_tmux_set_session_option "$session_name" "@aws-account-id" "$aws_account_id"
	fi

	# Set AWS region if available
	local aws_region="${AWS_REGION:-}"
	if [[ -n "$aws_region" ]]; then
		_tmux_set_session_option "$session_name" "@aws-region" "$aws_region"
	fi

	# Display authenticated message with available details
	local aws_ttl=""
	if [[ -n "${AWS_CREDENTIAL_EXPIRATION:-}" ]]; then
		aws_ttl="$(_tmux_get_session_option "$session_name" "@aws-credential-ttl")"
	fi

	_tmux_display_message "session" "$aws_profile" "$aws_account_id" "$aws_region" "$aws_ttl"

	if [[ "$start_shell" == "true" ]]; then
		"$SHELL" -i
	fi
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
	local start_shell=""

	while [[ $# -gt 0 ]]; do
		case "${1}" in
		--profile)
			shift
			aws_profile="$1"
			shift
			;;
		--start-shell)
			start_shell="--start-shell"
			shift
			;;
		*)
			echo "tmux-aws: auth-session: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	# Block re-authentication if already inside an aws-vault session
	if [[ -n "${AWS_VAULT:-}" ]]; then
		tmux display-message "AWS: already authenticated as '$AWS_VAULT' (open a new session for a different profile)"
		return 1
	fi

	# Get configured vault executable
	local aws_vault_path
	aws_vault_path="$(_tmux_get_aws_vault_path)"

	# Check if vault executable exists
	if ! command -v "$aws_vault_path" &>/dev/null; then
		tmux display-message "AWS: vault command not found ($aws_vault_path)"
		return 1
	fi

	tmux display-message "AWS: authenticating session as '$aws_profile'..."
	# Use aws-vault-compatible interface: exec <profile> -- <command>
	if ! "$aws_vault_path" exec "$aws_profile" -- \
		"$_tmux_aws_source_dir/tmux_aws.sh" exec-session --profile "$aws_profile" ${start_shell:+"$start_shell"}; then
		tmux display-message "AWS: authentication failed for '$aws_profile'"
		return 1
	fi
}

# Get session-level AWS information
#
# Usage:
#   get-session [-t target-session] profile|ttl|account-id|region
#
# Arguments:
#   -t target-session           - Target session (defaults to current session)
#   profile|ttl|account-id|region - What to retrieve
_tmux_get_session() {
	local target=""
	local what=""

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "${1}" in
		-t)
			shift
			target="$1"
			shift
			;;
		profile | ttl | account-id | region)
			what="$1"
			shift
			;;
		*)
			echo "tmux-aws: get-session: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	# If no target specified, use current session
	if [[ -z "$target" ]]; then
		target="$(tmux display -p '#{session_name}')"
	fi

	case "$what" in
	profile)
		local profile
		profile="$(_tmux_get_session_option "$target" "@aws-profile")"
		if [[ -n "$profile" ]]; then
			echo "$profile"
		fi
		;;
	ttl)
		local expiration
		expiration="$(_tmux_get_session_option "$target" "@aws-credential-expiration")"
		if [[ -n "$expiration" ]]; then
			local duration
			duration="$(_time_get_duration "$expiration")"
			if [[ -n "$duration" ]]; then
				_time_format_duration "$duration"
			fi
		fi
		;;
	account-id)
		local account_id
		account_id="$(_tmux_get_session_option "$target" "@aws-account-id")"
		if [[ -n "$account_id" ]]; then
			echo "$account_id"
		fi
		;;
	region)
		local region
		region="$(_tmux_get_session_option "$target" "@aws-region")"
		if [[ -n "$region" ]]; then
			echo "$region"
		fi
		;;
	esac
}

# Get window-level AWS information
#
# Usage:
#   get-window [-t target-window] profile|ttl|account-id|region
#
# Arguments:
#   -t target-window              - Target window (defaults to current window)
#   profile|ttl|account-id|region - What to retrieve
_tmux_get_window() {
	local target=""
	local what=""

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "${1}" in
		-t)
			shift
			target="$1"
			shift
			;;
		profile | ttl | account-id | region)
			what="$1"
			shift
			;;
		*)
			echo "tmux-aws: get-window: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	# If no target specified, use current window
	if [[ -z "$target" ]]; then
		target="$(tmux display -p '#{session_name}:#{window_index}')"
	fi

	case "$what" in
	profile)
		local profile
		profile="$(_tmux_get_window_option "$target" "@aws-profile")"
		if [[ -n "$profile" ]]; then
			echo "$profile"
		fi
		;;
	ttl)
		local expiration
		expiration="$(_tmux_get_window_option "$target" "@aws-credential-expiration")"
		if [[ -n "$expiration" ]]; then
			local duration
			duration="$(_time_get_duration "$expiration")"
			if [[ -n "$duration" ]]; then
				_time_format_duration "$duration"
			fi
		fi
		;;
	account-id)
		local account_id
		account_id="$(_tmux_get_window_option "$target" "@aws-account-id")"
		if [[ -n "$account_id" ]]; then
			echo "$account_id"
		fi
		;;
	region)
		local region
		region="$(_tmux_get_window_option "$target" "@aws-region")"
		if [[ -n "$region" ]]; then
			echo "$region"
		fi
		;;
	esac
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
			echo "tmux-aws: new-session: unknown argument: $1" >&2
			shift
			;;
		esac
	done

	local aws_account_id
	aws_account_id="$(_aws_get_option "$aws_profile" "sso_account_id" "")"

	local aws_region
	aws_region="$(_aws_get_option "$aws_profile" "sso_region" "")"

	if [[ -z "$aws_account_id" || -z "$aws_region" ]]; then
		tmux display-message "AWS: missing account or region for '$aws_profile'"
		return 1
	fi

	if [[ ! "$aws_account_id" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$aws_region" =~ ^[a-zA-Z0-9._-]+$ ]]; then
		tmux display-message "AWS: invalid account or region for '$aws_profile'"
		return 1
	fi

	local session_name="$aws_account_id-$aws_region"
	# Check if session already exists
	if tmux has-session -t "$session_name" 2>/dev/null; then
		tmux display-message "AWS: switching to existing session '$session_name'"
		# Session exists, switch to it
		tmux switch-client -t "$session_name" 2>/dev/null || tmux attach -t "$session_name"
		return
	fi

	# Create new detached session with aws-vault exec wrapping
	tmux new-session -d -s "$session_name" \
		"$_tmux_aws_source_dir/tmux_aws.sh" auth-session --profile "$aws_profile" --start-shell

	# Attach or switch to the new session
	tmux switch-client -t "$session_name" 2>/dev/null || tmux attach -t "$session_name"
}

# Main command router
#
# Arguments:
#   $1 - Command name
#   $@ - Command-specific arguments (passed to the respective function)
# Commands:
#   new-window    - Create a new tmux window with AWS profile configuration
#   exec-window   - Execute an interactive shell in a styled tmux window
#   new-session   - Create a new tmux session with AWS profile configuration
#   exec-session  - Execute an interactive shell in a styled tmux session
#   auth-session  - Authenticate current tmux session with AWS profile configuration
#   auth-window   - Authenticate current tmux window with AWS profile configuration
#   get-session   - Get session-level AWS information (profile|ttl|account-id|region)
#   get-window    - Get window-level AWS information (profile|ttl|account-id|region)
#   --version     - Print version and exit
main() {
	local command="${1:-}"
	shift || true

	case "$command" in
	--version)
		cat "$_tmux_aws_source_dir/../version.txt"
		;;
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
	get-session)
		_tmux_get_session "$@"
		;;
	get-window)
		_tmux_get_window "$@"
		;;
	*)
		echo "tmux-aws: unknown command: $command" >&2
		echo "Usage: tmux_aws.sh {--version|new-window|auth-window|new-session|auth-session|get-session|get-window}" >&2
		exit 1
		;;
	esac
}

main "$@"
