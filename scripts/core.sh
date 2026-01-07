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
