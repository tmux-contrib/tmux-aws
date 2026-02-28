#!/usr/bin/env bats

setup() {
	load test_helper
}

# =============================================================================
# _time_format_duration
# =============================================================================

@test "_time_format_duration: days and hours (>= 86400s)" {
	run _time_format_duration 90000 # 1d 1h
	[ "$status" -eq 0 ]
	[ "$output" = "1d 1h" ]
}

@test "_time_format_duration: multiple days" {
	run _time_format_duration 180000 # 2d 2h
	[ "$status" -eq 0 ]
	[ "$output" = "2d 2h" ]
}

@test "_time_format_duration: exactly 1 day" {
	run _time_format_duration 86400
	[ "$status" -eq 0 ]
	[ "$output" = "1d 0h" ]
}

@test "_time_format_duration: hours and minutes (3600-86399s)" {
	run _time_format_duration 24300 # 6h 45m
	[ "$status" -eq 0 ]
	[ "$output" = "6h 45m" ]
}

@test "_time_format_duration: exactly 1 hour" {
	run _time_format_duration 3600
	[ "$status" -eq 0 ]
	[ "$output" = "1h 0m" ]
}

@test "_time_format_duration: minutes and seconds (60-3599s)" {
	run _time_format_duration 1815 # 30m 15s
	[ "$status" -eq 0 ]
	[ "$output" = "30m 15s" ]
}

@test "_time_format_duration: exactly 1 minute" {
	run _time_format_duration 60
	[ "$status" -eq 0 ]
	[ "$output" = "1m 0s" ]
}

@test "_time_format_duration: seconds only (1-59s)" {
	run _time_format_duration 45
	[ "$status" -eq 0 ]
	[ "$output" = "45s" ]
}

@test "_time_format_duration: 1 second" {
	run _time_format_duration 1
	[ "$status" -eq 0 ]
	[ "$output" = "1s" ]
}

@test "_time_format_duration: expired (0s)" {
	run _time_format_duration 0
	[ "$status" -eq 0 ]
	[ "$output" = "X" ]
}

@test "_time_format_duration: empty input returns nothing" {
	run _time_format_duration ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "_time_format_duration: no argument returns nothing" {
	run _time_format_duration
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

# =============================================================================
# _time_get_epoch
# =============================================================================

@test "_time_get_epoch: parses ISO8601 with Z suffix" {
	run _time_get_epoch "2026-01-15T12:00:00Z"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	# Verify it's a reasonable epoch (after 2026-01-01)
	[ "$output" -gt 1767225600 ]
}

@test "_time_get_epoch: parses ISO8601 with +00:00 suffix" {
	run _time_get_epoch "2026-01-15T12:00:00+00:00"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	[ "$output" -gt 1767225600 ]
}

@test "_time_get_epoch: Z and +00:00 produce same result" {
	run _time_get_epoch "2026-01-15T12:00:00Z"
	local epoch_z="$output"

	run _time_get_epoch "2026-01-15T12:00:00+00:00"
	local epoch_offset="$output"

	[ "$epoch_z" = "$epoch_offset" ]
}

@test "_time_get_epoch: empty input returns nothing" {
	run _time_get_epoch ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "_time_get_epoch: no argument returns nothing" {
	run _time_get_epoch
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

# =============================================================================
# _time_get_duration
# =============================================================================

@test "_time_get_duration: future timestamp returns positive duration" {
	# Set expiration 1 hour from now
	local future
	future="$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

	run _time_get_duration "$future"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	# Should be roughly 3600 seconds (allow some slack for test execution)
	[ "$output" -ge 3590 ]
	[ "$output" -le 3610 ]
}

@test "_time_get_duration: past timestamp returns 0" {
	# Set expiration 1 hour ago
	local past
	past="$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

	run _time_get_duration "$past"
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]
}

@test "_time_get_duration: empty input returns nothing" {
	run _time_get_duration ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "_time_get_duration: no argument returns nothing" {
	run _time_get_duration
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}
