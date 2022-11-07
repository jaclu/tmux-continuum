#
#  I use an env var TMUX_BIN to point at the used tmux, defined in my
#  tmux.conf, in order to pick the version matching the server running,
#  or when the tmux bin is in fact tmate :)
#  If not found, it is set to whatever is in PATH, so should have no negative
#  impact. In all calls to tmux I use $TMUX_BIN instead in the rest of this
#  plugin.
#
[ -z "$TMUX_BIN" ] && TMUX_BIN="tmux"


get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$($TMUX_BIN show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

set_tmux_option() {
	local option="$1"
	local value="$2"
	$TMUX_BIN set-option -gq "$option" "$value"
}

# multiple tmux server detection helpers

current_tmux_server_pid() {
	echo "$TMUX_BIN" |
		cut -f2 -d","
}

all_tmux_processes() {
	# ignores `tmux source-file .tmux.conf` command used to reload tmux.conf
	local user_id=$(id -u)
	ps -u $user_id -o "command pid" |
		\grep "^tmux" |
		\grep -v "^$TMUX_BIN source"
}

number_tmux_processes_except_current_server() {
	all_tmux_processes |
		\grep -v " $(current_tmux_server_pid)$" |
		wc -l |
		sed "s/ //g"
}

number_current_server_client_processes() {
	$TMUX_BIN list-clients |
		wc -l |
		sed "s/ //g"
}

another_tmux_server_running_on_startup() {
	# there are 2 tmux processes (current tmux server + 1) on tmux startup
	[ "$(number_tmux_processes_except_current_server)" -gt 1 ]
}
