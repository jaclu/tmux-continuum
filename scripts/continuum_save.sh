#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/shared.sh"

supported_tmux_version_ok() {
	"$CURRENT_DIR/check_tmux_version.sh" "$SUPPORTED_VERSION"
}

get_interval() {
	get_tmux_option "$auto_save_interval_option" "$auto_save_interval_default"
}

auto_save_not_disabled() {
	[ "$(get_interval)" -gt 0 ]
}

enough_time_since_last_run_passed() {
	local last_saved_timestamp="$(get_tmux_option "$last_auto_save_option" "0")"
	local interval_minutes="$(get_interval)"
	local interval_seconds="$((interval_minutes * 60))"
	local next_run="$((last_saved_timestamp + $interval_seconds))"
	[ "$(current_timestamp)" -ge "$next_run" ]
}

fetch_and_run_tmux_resurrect_save_script() {
	local resurrect_save_script_path="$(get_tmux_option "$resurrect_save_path_option" "")"
	if [ -n "$resurrect_save_script_path" ]; then
		"$resurrect_save_script_path" "quiet" >/dev/null 2>&1 &
		set_last_save_timestamp
	fi
}

acquire_lock() {
	# Sometimes tmux starts multiple saves in parallel. We want only one
	# save to be running, otherwise we can get corrupted saved state.
	local lockdir_prefix="/tmp/tmux-continuum-$(current_tmux_server_pid)-lock-"
	# The following implements a lock that auto-expires after 100...200s.
	local lock_generation=$(($(date +%s) / 100))
	local lockdir1="${lockdir_prefix}${lock_generation}"
	local lockdir2="${lockdir_prefix}$(($lock_generation + 1))"
	if mkdir "$lockdir1"; then
		trap "rmdir "$lockdir1"" EXIT
		if mkdir "$lockdir2"; then
			trap "rmdir "$lockdir1" "$lockdir2"" EXIT
			return 0
		fi
	fi
	return 1 # Someone else has the lock.
}

main() {
	# This script may be triggered frequently, as often as every 10 seconds or less.
	# On slower systems, this frequent execution can cause noticeable delays, as
	# the script performs substantial processing that might take up to a second.
	# To improve responsiveness and reduce system load, a timestamp file is used
	# to limit full processing to once per minute.
	local f_next_check_timestamp="$CURRENT_DIR/continuum_next_check.timestamp"
	local t_now
	t_now="$(current_timestamp)"
	[ -f "$f_next_check_timestamp" ] && {
		local next_check
		read -r next_check <"$f_next_check_timestamp" # Using read instead of cat for efficiency
		# Check if the timestamp file contains a valid timestamp (positive integer)
		if [[ -n "$next_check" && "$next_check" =~ ^[0-9]+$ ]]; then
			[ "$t_now" -lt "$next_check" ] && return
		fi
	}
	echo "$((t_now + 60))" >"$f_next_check_timestamp"

	if supported_tmux_version_ok && auto_save_not_disabled && enough_time_since_last_run_passed && acquire_lock; then
		fetch_and_run_tmux_resurrect_save_script
	fi
}
main
