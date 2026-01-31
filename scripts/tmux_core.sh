#!/usr/bin/env bash

# Get tmux option with default fallback
#
# Arguments:
#   $1 - option name
#   $2 - default value
# Outputs:
#   Option value or default
_tmux_get_option() {
	local option="$1"
	local default="$2"
	local value

	value="$(tmux show-option -gqv "$option")"
	echo "${value:-$default}"
}

# Get tmux session option with default fallback
#
# Arguments:
#   $1 - target session
#   $2 - option name
#   $3 - default value (optional)
# Outputs:
#   Option value or default
_tmux_get_session_option() {
	local target="$1"
	local option="$2"
	local default="$3"
	local value

	value="$(tmux show-option -t "$target" -qv "$option" 2>/dev/null)"
	echo "${value:-$default}"
}

# Get tmux window option with default fallback
#
# Arguments:
#   $1 - target window
#   $2 - option name
#   $3 - default value (optional)
# Outputs:
#   Option value or default
_tmux_get_window_option() {
	local target="$1"
	local option="$2"
	local default="$3"
	local value

	value="$(tmux show-option -t "$target" -wqv "$option" 2>/dev/null)"
	echo "${value:-$default}"
}

# Set tmux session option
#
# Arguments:
#   $1 - target session
#   $2 - option name
#   $3 - option value
_tmux_set_session_option() {
	local target="$1"
	local option="$2"
	local value="$3"

	tmux set-option -t "$target" "$option" "$value"
}

# Set tmux window option
#
# Arguments:
#   $1 - target window
#   $2 - option name
#   $3 - option value
_tmux_set_window_option() {
	local target="$1"
	local option="$2"
	local value="$3"

	tmux set-window-option -t "$target" "$option" "$value"
}

# Get aws option with default fallback
#
# Arguments:
#   $1 - profile name
#   $2 - option name
#   $3 - default value
# Outputs:
#   Option value or default
_aws_get_option() {
	local profile="$1"
	local option="$2"
	local default="$3"
	local value

	value="$(aws configure get "$option" --profile "$profile")"
	echo "${value:-$default}"
}

# Parse ISO8601/RFC3339 timestamp to Unix epoch seconds
#
# Arguments:
#   $1 - ISO8601 timestamp (e.g., "2026-01-31T15:04:30Z" or "2026-01-31T15:04:30+00:00")
# Outputs:
#   Unix epoch seconds or empty string on error
_time_get_epoch() {
	local timestamp="$1"
	[[ -z "$timestamp" ]] && return

	# Remove trailing Z or timezone offset for BSD date compatibility
	local clean_ts="${timestamp%Z}"
	clean_ts="${clean_ts%+00:00}"

	# Try GNU date first (Linux)
	local epoch
	if epoch="$(date -d "$timestamp" +%s 2>/dev/null)"; then
		echo "$epoch"
		return
	fi

	# Fall back to BSD date (macOS)
	if epoch="$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$clean_ts" +%s 2>/dev/null)"; then
		echo "$epoch"
	fi
}

# Calculate seconds remaining until expiration
#
# Arguments:
#   $1 - ISO8601 expiration timestamp
# Outputs:
#   Seconds remaining (0 if expired, empty if invalid)
_time_get_duration() {
	local expiration="$1"
	[[ -z "$expiration" ]] && return

	local exp_epoch
	exp_epoch="$(_time_get_epoch "$expiration")"
	[[ -z "$exp_epoch" ]] && return

	local now_epoch
	now_epoch="$(date +%s)"

	local duration=$((exp_epoch - now_epoch))
	if [[ $duration -lt 0 ]]; then
		echo "0"
	else
		echo "$duration"
	fi
}

# Convert seconds to adaptive human-readable format
#
# Arguments:
#   $1 - TTL in seconds
# Outputs:
#   Adaptive format based on time remaining:
#     >= 24 hours: "2d 5h" (days and hours)
#     1-24 hours:  "6h 45m" (hours and minutes)
#     1-60 min:    "30m 15s" (minutes and seconds)
#     < 1 minute:  "45s" (seconds only)
#     Expired:     "EXPIRED"
_time_format_duration() {
	local duration="$1"
	[[ -z "$duration" ]] && return

	local days=$((duration / 86400))
	local hours=$(((duration % 86400) / 3600))
	local minutes=$(((duration % 3600) / 60))
	local seconds=$((duration % 60))

	# Adaptive format based on time remaining
	if [[ $duration -ge 86400 ]]; then
		# >= 24 hours: show days and hours only
		printf "%dd %dh" "$days" "$hours"
	elif [[ $duration -ge 3600 ]]; then
		# 1-24 hours: show hours and minutes only
		printf "%dh %dm" "$hours" "$minutes"
	elif [[ $duration -ge 60 ]]; then
		# 1-60 minutes: show minutes and seconds
		printf "%dm %ds" "$minutes" "$seconds"
	elif [[ $duration -gt 0 ]]; then
		# < 1 minute: show seconds only
		printf "%ds" "$seconds"
	else
		# Expired
		echo "X"
	fi
}
