# -*- tab-width:  4 -*- ;; Emacs
# vi: set tabstop=8     :: Vi/ViM
############################################################ IDENT(1)
#
# $Title: csh(1) semi-subroutine file $
# $Copyright: 2015-2019 Devin Teske. All rights reserved. $
# $FrauBSD: //github.com/FrauBSD/secure_thumb/etc/ssh.csh 2019-10-16 10:23:27 +0000 freebsdfrau $
#
############################################################ INFORMATION
#
# Add to .cshrc:
#       source ~/etc/ssh.csh
#
############################################################ GLOBALS

#
# Global exit status variables
#
setenv SUCCESS 0
setenv FAILURE 1

#
# Are we running interactively?
#
set interactive = 0
if ( $?prompt ) set interactive = 1

#
# OS Specifics
# NB: Requires uname(1) -- from base system
#
if ( ! $?UNAME_s ) setenv UNAME_s `uname -s`

#
# For dialog(1) and Xdialog(1) menus -- mainly cvspicker in FUNCTIONS below
#
set DIALOG_MENU_TAGS = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

#
# Default directory to store dialog(1) and Xdialog(1) temporary files
#
if ( ! $?DIALOG_TMPDIR ) set DIALOG_TMPDIR = "/tmp"

#
# Literals
# NB: Required by escape, shfunction, and eshfunction
#
set tab = "	" # Must be a literal tab
set nl = "\
" # END-QUOTE

############################################################ ALIASES

unalias quietly >& /dev/null
alias quietly '\!* >& /dev/null'

quietly unalias have
alias have 'which \!* >& /dev/null'

quietly unalias eval2
alias eval2 'echo \!*; eval \!*'

quietly unalias escape
alias escape "awk '"'                                                       \\
	BEGIN { a = sprintf("%c",39) }                                      \\
	{                                                                   \\
		gsub(a,"&\\\\&&")                                           \\
		gsub(/ /, a "\\ " a)                                        \\
		gsub(/\t/, a "$tab:q" a)                                    \\
		buf=buf a "$nl:q" a $0                                      \\
	}                                                                   \\
	END { print a substr(buf,8) a }                                     \\
'\'

# ssh-agent [ssh-agent options]
#
# Override ``ssh-agent'' to call an alias (you can always call the real binary
# by executing /usr/bin/ssh-agent) that launches a background ssh-agent that
# times-out in 30 minutes.
#
# Will evaluate the output of /usr/bin/ssh-agent (the real ssh-agent) called
# with either a known-secure set of arguments (if none are provided) or the
# unmodified arguments to this alias.
#
# Purpose is to prevent memorizing something like ``eval "`ssh-agent ...`"''
# but instead simply ``ssh-agent [...]''.
#
# This allows you to, for example:
#
# 	ssh-agent
# 	: do some ssh-add
# 	: do some commits
# 	ssh-agent -k
# 	: or instead of ``ssh-agent -k'' just wait 30m for it to die
#
# NB: Requires ssh-agent -- from base system
#
quietly unalias ssh-agent
alias ssh-agent 'eval `ssh-agent -c -t 1800 \!*`'

# function $name $code
#
# Define a ``function'' that runs in the current namespace.
#
# NB: Evaluated context (using `eval') may not merge namespace immediately.
# NB: Commands considered unsafe by the shell may not work in this context.
# NB: Using builtins such as if, while, switch, and others will invoke an adhoc
# parser that appends to the history.
#
set alias_function = '                                                       \
	set __name = $argv_function[1]                                       \
	set __body = $argv_function[2]:q                                     \
	set __var  = "$__name:as/-/_/"                                       \
	set __argv = argv_$__var                                             \
	set __alias = alias_$__var                                           \
	set __body = "set ALIASNAME = $__name; "$__body:q                    \
	alias $__name "set $__argv = (\!"\*");"$__body:q                     \
	unset $__alias                                                       \
	set $__alias = $__body:q                                             \
'
quietly unalias function
alias function "set argv_function = (\!*); "$alias_function:q

############################################################ FUNCTIONS

# cmdsubst $var [$env ...] $cmd
#
# Evaluate $cmd via /bin/sh and store the results in $var.
# Like "set $var = `env $env /bin/sh -c $cmd:q`" except output is preserved.
#
# NB: This function is unused in this file
# NB: Requires escape alias -- from this file
# NB: Requires /bin/sh -- from base system
#
quietly unalias cmdsubst
function cmdsubst '                                                          \
	set __var = $argv_cmdsubst[1]                                        \
	set __argc = $#argv_cmdsubst                                         \
	@ __argc--                                                           \
	set __penv = ($argv_cmdsubst[2-$__argc]:q)                           \
	@ __argc++                                                           \
	set __cmd = $argv_cmdsubst[$__argc]:q                                \
	set __out = `env $__penv:q /bin/sh -c $__cmd:q | escape`             \
	eval set $__var = $__out:q                                           \
'

# evalsubst [$env ...] $cmd
#
# Execute $cmd via /bin/sh and evaluate the results.
# Like "eval `env $env /bin/sh -c $cmd:q`" except output is preserved.
#
# NB: This function is unused in this file
# NB: Requires escape alias -- from this file
# NB: Requires /bin/sh -- from base system
#
quietly unalias evalsubst
function evalsubst '                                                         \
	set __argc = $#argv_evalsubst                                        \
	@ __argc--                                                           \
	set __penv = ($argv_evalsubst[1-$__argc])                            \
	@ __argc++                                                           \
	eval eval `env $__penv:q /bin/sh -c                                 \\
		$argv_evalsubst[$__argc]:q | escape`                         \
'

# shfunction $name $code
#
# Define a ``function'' that runs under /bin/sh.
# NB: No alias is created if one already exists.
#
quietly unalias shfunction
function shfunction '                                                        \
	set __name = $argv_shfunction[1]                                     \
	set __argc = $#argv_shfunction                                       \
	@ __argc--                                                           \
	set __penv = ($argv_shfunction[2-$__argc]:q)                         \
	@ __argc++                                                           \
	set __body = $argv_shfunction[$__argc]:q                             \
	set __var = "$__name:as/-/_/"                                        \
	set __alias = shalias_$__var                                         \
	set __func = shfunc_$__var                                           \
	set __interp = "env $__penv:q /bin/sh -c "\"\$"${__alias}:q"\"       \
	set __body = "local FUNCNAME=$__var ALIASNAME=$__name; $__body:q"    \
	set __body = "$__var(){$nl:q$__body:q$nl:q}"                         \
	set $__func = $__body:q                                              \
	set $__alias = $__body:q\;\ $__var\ \"\$@\"                          \
	have $__name || alias $__name "$__interp /bin/sh"                    \
'

# eshfunction $name $code
#
# Define a ``function'' that runs under /bin/sh but produces output that is
# evaluated in the current shell's namespace.
#
# NB: No alias is created if one already exists.
#
quietly unalias eshfunction
function eshfunction '                                                       \
	set __name = $argv_eshfunction[1]                                    \
	set __argc = $#argv_eshfunction                                      \
	@ __argc--                                                           \
	set __penv = ($argv_eshfunction[2-$__argc]:q)                        \
	@ __argc++                                                           \
	set __body = $argv_eshfunction[$__argc]:q                            \
	set __var = "$__name:as/-/_/"                                        \
	set __alias = shalias_$__var                                         \
	set __func = shfunc_$__var                                           \
	set __interp = "env $__penv:q /bin/sh -c "\"\$"${__alias}:q"\"       \
	set __interp = "$__interp:q /bin/sh \!"\*" | escape"                 \
	set __body = "local FUNCNAME=$__var ALIASNAME=$__name; $__body:q"    \
	set __body = "$__var(){$nl:q$__body:q$nl:q}"                         \
	set $__func = $__body:q                                              \
	set $__alias = $__body:q\;\ $__var\ \"\$@\"                          \
	have $__name || alias $__name                                       \\
		'\''eval eval `'\''$__interp:q'\''`'\''                      \
'

# quietly $cmd ...
#
# Execute /bin/sh $cmd while sending stdout and stderr to /dev/null.
#
shfunction quietly '"$@" > /dev/null 2>&1'

# have name
#
# Silently test for name as an available command, builtin, or other executable.
#
shfunction have 'type "$@" > /dev/null 2>&1'

# eval2 $cmd ...
#
# Print $cmd on stdout before executing it. 
#
shfunction eval2 'echo "$*"; eval "$@"'

# fprintf $fd $fmt [$opts ...]
#
# Like printf, except allows you to print to a specific file-descriptor. Useful
# for printing to stderr (fd=2) or some other known file-descriptor.
#
quietly unalias fprintf
shfunction fprintf '                                                         \
	fd=$1                                                                \
	[ $# -gt 1 ] || return ${FAILURE:-1}                                 \
	shift 1                                                              \
	printf "$@" >&$fd                                                    \
'

# eprintf $fmt [$opts ...]
#
# Like printf, except send output to stderr (fd=2).
#
quietly unalias eprintf
shfunction eprintf \
	'__fprintf=$shfunc_fprintf:q' \
'                                                                            \
	eval "$__fprintf"                                                    \
	fprintf 2 "$@"                                                       \
'

# ssh-agent-dup [-aqn]
#
# Connect to an open/active ssh-agent session available to the currently
# authenticated user. If more than one ssh-agent is available and the `-n' flag
# is not given, provide a menu list of open/active sessions available. Allows
# the user to quickly duplicate access to an ssh-agent launched in another
# interactive session on the same machine or for switching between agents.
#
# This allows you to, for example:
#
# 	(in shell session A)
# 	ssh-agent
# 	(in shell session B)
# 	ssh-agent-dup
# 	(now both sessions A and B can use the same agent)
#
# No menu is presented if only a single agent session is available (the open
# session is duplicated for the active shell session). If more than one agent
# is available, a menu is presented. The menu choice becomes the active agent.
#
# If `-a' is present, list all readable agent sockets, not just those owned by
# the currently logged-in user.
#
# If `-q' is present, do not list agent nor keys.
#
# If `-n' is present, run non-interactively (good for scripts; pedantic).
#
# NB: Requires cexport() dialog_menutag() dialog_menutag2help() have()
#     quietly() -- from this file
# NB: Requires $DIALOG_TMPDIR $DIALOG_MENU_TAGS -- from this file
# NB: Requires awk(1) cat(1) grep(1) id(1) ls(1) ps(1) ssh-add(1) stat(1)
#     -- from base system
#
shfunction cexport '                                                         \
	local item key value                                                 \
	while [ $# -gt 0 ]; do                                               \
		item="$1"                                                    \
		key="${item%%=*}"                                            \
		value="${item#"$key"=}"                                      \
		if [ "$interactive" ]; then                                  \
			echo "setenv $key $value" >&2                        \
		fi                                                           \
		echo "setenv $key $value"                                    \
		export "$item"                                               \
		shift 1 # item                                               \
	done                                                                 \
'
quietly unalias cexport # sh only
quietly unalias ssh-agent-dup
eshfunction ssh-agent-dup \
	'DIALOG_MENU_TAGS=$DIALOG_MENU_TAGS:q' \
	'DIALOG_TMPDIR=$DIALOG_TMPDIR:q' \
	'__cexport=$shfunc_cexport:q' \
	'__dialog_menutag=$shfunc_dialog_menutag:q' \
	'__dialog_menutag2help=$shfunc_dialog_menutag2help:q' \
	'__have=$shfunc_have:q' \
	'__quietly=$shfunc_quietly:q' \
' \
	eval "$__cexport"                                                    \
	eval "$__dialog_menutag"                                             \
	eval "$__dialog_menutag2help"                                        \
	eval "$__have"                                                       \
	eval "$__quietly"                                                    \
	                                                                     \
	local t=1s # ssh-add(1) timeout                                      \
	local list_all= quiet= interactive=1 noninteractive=                 \
	local sockets=                                                       \
	local ucomm owner socket owner pid current_user                      \
	                                                                     \
	local OPTIND=1 OPTARG flag                                           \
	while getopts anq flag; do                                           \
		case "$flag" in                                              \
		a) list_all=1 ;;                                             \
		n) noninteractive=1 interactive= ;;                          \
		q) quiet=1 ;;                                                \
		\?|*)                                                        \
			[ "$noninteractive" ] ||                             \
				echo "$ALIASNAME [-aq]" | ${LOLCAT:-cat} >&2 \
			return ${FAILURE:-1}                                 \
		esac                                                         \
	done                                                                 \
	shift $(( $OPTIND - 1 ))                                             \
	                                                                     \
	case "$UNAME_s" in                                                   \
	*BSD) owner="-f%Su" ;;                                               \
	*) owner="-c%U"                                                      \
	esac                                                                 \
	                                                                     \
	current_user=$( id -nu )                                             \
	for socket in /tmp/ssh-*/agent.[0-9]*; do                            \
		# Must exist as a socket                                     \
		[ -S "$socket" ] || continue                                 \
		                                                             \
		# Must end in numbers-only (after trailing dot)              \
		pid="${socket##*.}"                                          \
		[ "$pid" -a "$pid" = "${pid#*[\!0-9]}" ] || continue         \
		pid=$(( $pid + 1 )) # socket num is one below agent PID      \
		                                                             \
		# Must be a running pid and an ssh or ssh-agent              \
		ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )                 \
		if ! [ "$ucomm" = ssh-agent ]; then                          \
			# This could be a forwarded agent                    \
			pid=$(( $pid - 1 ))                                  \
			ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )         \
			[ "$ucomm" = sshd ] || continue                      \
		fi                                                           \
		                                                             \
		# Must be owned by the current user unless -a is used        \
		# NB: When -a is used, the socket still has to be readable   \
		if [ ! "$list_all" ]; then                                   \
			owner=$( stat $owner "$socket" 2> /dev/null ) ||     \
				continue                                     \
			[ "$owner" = "$current_user" ] || continue           \
		fi                                                           \
		                                                             \
		sockets="$sockets $socket"                                   \
	done                                                                 \
	                                                                     \
	sockets="${sockets# }"                                               \
	if [ ! "$sockets" ]; then                                            \
		if [ ! "$noninteractive" ]; then                             \
			local msg="$ALIASNAME: No agent sockets available"   \
			echo "$msg" | ${LOLCAT:-cat} >&2                     \
		fi                                                           \
		return ${FAILURE:-1}                                         \
	fi                                                                   \
	if [ "${sockets}" = "${sockets%% *}" ]; then                         \
		# Only one socket found                                      \
		pid=$(( ${sockets##*.} + 1 ))                                \
		ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )                 \
		if [ "$ucomm" = ssh-agent ]; then                            \
			cexport SSH_AUTH_SOCK="$sockets"                 \\\\\
				SSH_AGENT_PID="$pid"                         \
		else                                                         \
			# This could be a forwarded agent                    \
			pid=$(( $pid - 1 ))                                  \
			ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )         \
			if [ "$ucomm" = sshd ]; then                         \
				cexport SSH_AUTH_SOCK="$sockets"         \\\\\
					SSH_AGENT_PID="$pid"                 \
			else                                                 \
				cexport SSH_AUTH_SOCK="$sockets"             \
			fi                                                   \
		fi                                                           \
		[ "$SSH_AGENT_PID" -a ! "$quiet" ] && # show process         \
			[ "$interactive" ] &&                                \
			ps -p "$SSH_AGENT_PID" | ${LOLCAT:-cat} >&2          \
		# dump fingerprints from newly configured agent              \
		if ! [ "$quiet" -o "$noninteractive" ]; then                 \
			echo "# NB: Use \`ssh-agent -k'\''"              \\\\\
			     "to kill this agent"                            \
			if have timeout; then                                \
				timeout $t ssh-add -l                        \
			else                                                 \
				ssh-add -l                                   \
			fi                                                   \
		fi | ${LOLCAT:-cat} >&2                                      \
		return ${SUCCESS:-0}                                         \
	fi                                                                   \
	                                                                     \
	# There is more than one agent available                             \
	[ "$noninteractive" ] && return ${FAILURE:-1}                        \
	                                                                     \
	#                                                                    \
	# If we do not have dialog(1), just print the possible values        \
	#                                                                    \
	if ! have dialog; then                                               \
		local prefix="%3s"                                           \
		local fmt="$prefix %5s %-20s %s\n"                           \
		local num=0 choice                                           \
		local identities nloaded                                     \
		                                                             \
		sockets=$( command ls -tr $sockets ) # asc order by age      \
		printf "$fmt" "" PID USER+NKEYS COMMAND >&2                  \
		for socket in $sockets; do                                   \
			num=$(( $num + 1 ))                                  \
			pid=$(( ${socket##*.} + 1 ))                         \
			ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )         \
			[ "$ucomm" = ssh-agent ] || pid=$(( $pid - 1 ))      \
			nkeys=0                                              \
			identities=$(                                        \
				unset interactive                            \
				cexport SSH_AUTH_SOCK="$socket"              \
				if have timeout; then                        \
					timeout $t ssh-add -l                \
				else                                         \
					ssh-add -l                           \
				fi                                           \
			) && nkeys=$( echo "$identities" | grep -c . )       \
			printf "$fmt" $num: "$pid"                       \\\\\
				"$( ps -p $pid -o user= )"+"$nkeys"      \\\\\
				"$( ps -p $pid -o command= )" |              \
				${LOLCAT:-cat} >&2                           \
		done                                                         \
		echo >&2                                                     \
		echo -n "Select a number [$num]: " | ${LOLCAT:-cat} >&2      \
		read choice                                                  \
		: ${choice:=$num}                                            \
		case "$choice" in                                            \
		""|*[\!0-9]*)                                                \
			echo "$ALIASNAME: Invalid choice [$choice]" |        \
				${LOLCAT:-cat} >&2                           \
			return ${FAILURE:-1} ;;                              \
		esac                                                         \
		if [ $choice -gt $num -o $choice -lt 1 ]; then               \
			echo "$ALIASNAME: Choice out of range [$choice]" |   \
				${LOLCAT:-cat} >&2                           \
			return ${FAILURE:-1}                                 \
		fi                                                           \
		set -- $sockets                                              \
		eval socket=\"\${$choice}\"                                  \
		                                                             \
		pid=$(( ${socket##*.} + 1 ))                                 \
		ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )                 \
		if [ "$ucomm" = ssh-agent ]; then                            \
			cexport SSH_AUTH_SOCK="$socket"                  \\\\\
				SSH_AGENT_PID="$pid"                         \
		else                                                         \
			# This could be a forwarded agent                    \
			pid=$(( $pid - 1 ))                                  \
			ucomm=$( ps -p $pid -o ucomm= 2> /dev/null )         \
			if [ "$ucomm" = sshd ]; then                         \
				cexport SSH_AUTH_SOCK="$socket"          \\\\\
					SSH_AGENT_PID="$pid"                 \
			else                                                 \
				cexport SSH_AUTH_SOCK="$socket"              \
			fi                                                   \
		fi                                                           \
	else                                                                 \
		local menu_list=                                             \
		                                                             \
		sockets=$( command ls -1t $sockets ) # desc order by age     \
		have timeout || t=                                           \
		menu_list=$( echo "$sockets" |                               \
			awk -v t="$t" -v tags="$DIALOG_MENU_TAGS" '\''       \
			{                                                    \
				if (++tagn > length(tags)) exit              \
				if (\!match($0, /[[:digit:]]+$/)) next       \
				pid = substr($0, RSTART, RLENGTH) + 1        \
				cmd = sprintf("ps -p %u -o user=", pid)      \
				cmd | getline user                           \
				close(cmd)                                   \
				cmd = sprintf("ps -p %u -o command=", pid)   \
				cmd | getline command                        \
				close(cmd)                                   \
				nloaded = 0                                  \
				cmd = "SSH_AUTH_SOCK=" $0                    \
				if (t != "") cmd = cmd " timeout " t         \
				cmd = cmd " ssh-add -l"                      \
				while (cmd | getline identity) {             \
					nloaded += identity ~ /^[[:digit:]]/ \
				}                                            \
				close(cmd)                                   \
				printf "'\''\'\''%s\'\''\ \'\''%s\'\''\ \'\''%s\'\'''\''\n", \
					substr(tags, tagn, 1),               \
					sprintf("pid %u %s+%u %s", pid,      \
						user, nloaded, command),     \
					sprintf("%s %s",                     \
						"SSH_AUTH_SOCK=" $0,         \
						"SSH_AGENT_PID=" pid)        \
			}'\''                                                \
		)                                                            \
		                                                             \
		local prompt="Pick an ssh-agent to duplicate (user+nkeys):"  \
		eval dialog                                              \\\\\
			--clear --title "'\''$ALIASNAME'\''" --item-help \\\\\
			--menu "'\''$prompt'\''" 17 55 9 $menu_list      \\\\\
			>&2 2> "$DIALOG_TMPDIR/dialog.menu.$$"               \
		local retval=$?                                              \
		                                                             \
		# Return if "Cancel" (-1) or ESC (255)                       \
		[ $retval -eq ${SUCCESS:-0} ] || return $retval              \
		                                                             \
		local tag="$( dialog_menutag )"                              \
		cexport $( eval dialog_menutag2help                      \\\\\
			"'\''$tag'\''" $menu_list )                          \
	fi                                                                   \
	                                                                     \
	# Attempt to show the running agent                                  \
	[ "$SSH_AGENT_PID" -a ! "$quiet" ] &&                                \
		ps -p "$SSH_AGENT_PID" | ${LOLCAT:-cat} >&2                  \
	                                                                     \
	# Attempt to dump fingerprints from newly configured agent           \
	if [ ! "$quiet" ]; then                                              \
		echo "# NB: Use \`$ALIASNAME'\'' to select different agent"  \
		echo "# NB: Use \`ssh-agent -k'\'' to kill this agent"       \
		if have timeout; then                                        \
			timeout $t ssh-add -l                                \
		else                                                         \
			ssh-add -l                                           \
		fi                                                           \
	fi | ${LOLCAT:-cat} >&2                                              \
'

# openkey [-hv]
#
# Mounts my F.o thumb
#
# NB: Requires eprintf() eval2() have() -- from this file
# NB: Requires awk(1) df(1) id(1) mount(8) -- from base system
#
quietly unalias openkey
shfunction openkey \
	'__fprintf=$shfunc_fprintf:q' \
	'__eprintf=$shfunc_eprintf:q' \
	'__eval2=$shfunc_eval2:q' \
	'__have=$shfunc_have:q' \
'                                                                            \
	eval "$__fprintf"                                                    \
	eval "$__eprintf"                                                    \
	eval "$__eval2"                                                      \
	eval "$__have"                                                       \
	[ "$UNAME_s" = "FreeBSD" ] ||                                        \
		{ echo "$FUNCNAME: FreeBSD only!" >&2; return 1; }           \
	local OPTIND=1 OPTARG flag verbose= sudo=                            \
	while getopts hv flag; do                                            \
		case "$flag" in                                              \
		v) verbose=1 ;;                                              \
		*) local optfmt="\t%-4s %s\n"                                \
		   eprintf "Usage: $FUNCNAME [-hv]\n"                        \
		   eprintf "OPTIONS:\n"                                      \
		   eprintf "$optfmt" "-h"                                \\\\\
		           "Print this text to stderr and return."           \
		   eprintf "$optfmt" "-v"                                \\\\\
		           "Print verbose debugging information."            \
		   return ${FAILURE:-1}                                      \
		esac                                                         \
	done                                                                 \
	shift $(( $OPTIND - 1 ))                                             \
	if [ "$( id -u )" != "0" ]; then                                     \
		if have sr; then                                             \
			sudo=sr                                              \
		elif have sudo; then                                         \
			sudo=sudo                                            \
		fi || {                                                      \
			eprintf "$FUNCNAME: not enough privileges\n"         \
			return ${FAILURE:-1}                                 \
		}                                                            \
	fi                                                                   \
	df -l /mnt | awk '\''                                               \\
		$NF == "/mnt" { exit found++ } END { exit \!found }         \\
	'\'' || ${verbose:+eval2} $sudo mount /mnt || return                 \
	local nfail=3                                                        \
	while [ $nfail -gt 0 ]; do                                           \
		/mnt/mount.sh -d${verbose:+v} && break                       \
		nfail=$(( $nfail - 1 ))                                      \
	done                                                                 \
	[ "$verbose" ] && df -hT /mnt/* | ( awk '\''                        \\
		NR == 1 { print > "/dev/stderr"; next } 1                   \\
	'\'' | sort -u ) 2>&1                                                \
	return ${SUCCESS:-0}                                                 \
'

# closekey [-ehv]
#
# Unmounts my F.o thumb
#
# NB: Requires eprintf() have() -- from this file
# NB: Requires awk(1) camcontrol(8) df(1) id(1) umount(8) -- from base system
#
quietly unalias closekey
shfunction closekey \
	'__fprintf=$shfunc_fprintf:q' \
	'__eprintf=$shfunc_eprintf:q' \
	'__have=$shfunc_have:q' \
'                                                                            \
	eval "$__fprintf"                                                    \
	eval "$__eprintf"                                                    \
	eval "$__have"                                                       \
	local OPTIND=1 OPTARG flag eject= verbose= sudo=                     \
	while getopts ehv flag; do                                           \
		case "$flag" in                                              \
		e) eject=1 ;;                                                \
		v) verbose=1 ;;                                              \
		*) local optfmt="\t%-4s %s\n"                                \
		   eprintf "Usage: $FUNCNAME [-ehv]\n"                       \
		   eprintf "OPTIONS:\n"                                      \
		   eprintf "$optfmt" "-e"                                \\\\\
		           "Eject USB media (using "\`"camcontrol eject'\'')." \
		   eprintf "$optfmt" "-h"                                \\\\\
		           "Print this text to stderr and return."           \
		   eprintf "$optfmt" "-v"                                \\\\\
		           "Print verbose debugging information."            \
		   return ${FAILURE:-1}                                      \
		esac                                                         \
	done                                                                 \
	shift $(( $OPTIND - 1 ))                                             \
	if [ "$( id -u )" != "0" ]; then                                     \
		if have sr; then                                             \
			sudo=sr                                              \
		elif have sudo; then                                         \
			sudo=sudo                                            \
		fi || {                                                      \
			eprintf "$FUNCNAME: not enough privileges\n"         \
			return ${FAILURE:-1}                                 \
		}                                                            \
	fi                                                                   \
	[ ! -f "/mnt/umount.sh" ] ||                                         \
		${verbose:+eval2} /mnt/umount.sh ${verbose:+-v} || return    \
	[ ! "$eject" ] || daN=$( df -l /mnt | awk '\''                      \\
		$NF == "/mnt" && match($0, "^/dev/[[:alpha:]]+[[:digit:]]+") { \\
			print substr($0, 6, RLENGTH - 5)                    \\
			exit found++                                        \\
		} END { exit ! found }                                      \\
	'\'' ) || daN=$(                                                     \
		[ "$sudo" -a "$verbose" ] && echo $sudo camcontrol devlist >&2 \
		$sudo camcontrol devlist | awk '\''                         \\
		BEGIN {                                                     \\
			camfmt = "^<%s>[[:space:]]+[^(]*"                   \\
	                                                                    \\
			disk[nfind = 0] = "da[[:digit:]]+"                  \\
			find[nfind++] = "USB Flash Disk 1100"               \\
	                                                                    \\
			#disk[nfind] = "device_pattern"                     \\
			#find[nfind++] = "model_pattern"                    \\
		}                                                           \\
		found = 0                                                   \\
		{                                                           \\
			for (n = 0; n < nfind; n++)                         \\
			{                                                   \\
				if (\!match($0, sprintf(camfmt, find[n])))  \\
					continue                            \\
				devicestr = substr($0, RSTART + RLENGTH + 1)\\
				gsub(/\).*/, "", devicestr)                 \\
				ndevs = split(devicestr, devices, /,/)      \\
				for (d = 1; d <= ndevs; d++) {              \\
					if (devices[d] !~ "^" disk[n] "$")  \\
						continue                    \\
					found = 1                           \\
					break                               \\
				}                                           \\
				if (found) break                            \\
			}                                                   \\
		}                                                           \\
		found && $0 = devices[d] { print; exit }                    \\
		END { exit \!found }                                        \\
	'\'' ) || return                                                    \\
	[ ! -f "/mnt/umount.sh" ] ||                                         \
		${verbose:+eval2} /mnt/umount.sh ${verbose:+-v} || return    \
	! df -l /mnt | awk '\''                                             \\
	               $NF=="/mnt"{exit found++}END{exit \!found}'\'' ||     \
		${verbose:+eval2} $sudo umount /mnt || return                \
	[ "$eject" -a "$daN" ] &&                                            \
		${verbose:+eval2} $sudo camcontrol eject "$daN"              \
	return ${SUCCESS:-0}                                                 \
'

# loadkeys [OPTIONS] [key ...]
#
# Load my SSH private keys from my F.o thumb. The `key' argument is to the
# SSH private keyfile's suffix; in example, "sf" for "id_rsa.sf" or "f.o" for
# "id_rsa.f.o" or "gh" for "id_rsa.gh".
#
# For example, to load the Sourceforge.net key, F.o key, and Github key:
# 	loadkeys sf f.o gh
#
# OPTIONS:
# 	-c           Close USB media after loading keys.
# 	-e           Close and eject USB media after loading keys.
# 	-h           Print this text to stderr and return.
# 	-k           Kill running ssh-agent(1) and launch new one.
# 	-n           Start a new ssh-agent, ignoring current one.
# 	-t timeout   Timeout. Only used if starting ssh-agent(1).
# 	-v           Print verbose debugging information.
#
# NB: Requires closekey() colorize() eprintf() openkey() ssh-agent() quietly()
#     ssh-agent-dup() -- from this file
# NB: Requires awk(1) kill(1) ps(1) ssh-add(1) -- from base system
#
quietly unalias loadkeys
shfunction loadkeys \
	'__fprintf=$shfunc_fprintf:q' \
	'__eprintf=$shfunc_eprintf:q' \
	'__openkey=$shfunc_openkey:q' \
	'__quietly=$shfunc_quietly:q' \
	'__colorize=$shfunc_colorize:q' \
	'__closekey=$shfunc_closekey:q' \
	'__ssh_agent_dup=$shfunc_ssh_agent_dup:q' \
'                                                                            \
	eval "$__fprintf"                                                    \
	eval "$__eprintf"                                                    \
	eval "$__openkey"                                                    \
	eval "$__quietly"                                                    \
	eval "$__colorize"                                                   \
	eval "$__closekey"                                                   \
	eval "$__ssh_agent_dup"                                              \
	local OPTIND=1 OPTARG flag close= eject= kill= new= timeout= verbose=\
	while getopts cehknt:v flag; do                                      \
		case "$flag" in                                              \
		c) close=1 ;;                                                \
		e) close=1 eject=1 ;;                                        \
		k) kill=1 ;;                                                 \
		n) new=1 ;;                                                  \
		v) verbose=1 ;;                                              \
		t) timeout="$OPTARG" ;;                                      \
		*) local optfmt="\t%-12s %s\n"                               \
		   eprintf "Usage: $FUNCNAME [OPTIONS] [key ...]\n"          \
		   eprintf "OPTIONS:\n"                                      \
		   eprintf "$optfmt" "-c"                                \\\\\
		           "Close USB media after loading keys."             \
		   eprintf "$optfmt" "-e"                                \\\\\
		           "Close and eject USB media after loading keys."   \
		   eprintf "$optfmt" "-h"                                \\\\\
		           "Print this text to stderr and return."           \
		   eprintf "$optfmt" "-k"                                \\\\\
		           "Kill running ssh-agent(1) and launch new one."   \
		   eprintf "$optfmt" "-n"                                \\\\\
		           "Start a new ssh-agent, ignoring current one."    \
		   eprintf "$optfmt" "-t timeout"                        \\\\\
		           "Timeout. Only used if starting ssh-agent(1)."    \
		   eprintf "$optfmt" "-v"                                \\\\\
		           "Print verbose debugging information."            \
		   return ${FAILURE:-1}                                      \
		esac                                                         \
	done                                                                 \
	shift $(( $OPTIND - 1 ))                                             \
	[ "$kill" ] && quietly ssh-agent -k                                  \
	if [ "$new" ]; then                                                  \
		ssh-agent ${timeout:+-t"$timeout"} ||                        \
			return ${FAILURE:-1}                                 \
	elif quietly kill -0 "$SSH_AGENT_PID"; then                          \
		: already running                                            \
	elif [ "$SSH_AUTH_SOCK" ] && quietly ssh-add -l; then                \
		eval2 export SSH_AGENT_PID=$( lsof -t -- $SSH_AUTH_SOCK )    \
	else                                                                 \
		if ! ssh_agent_dup -q; then                                  \
			ssh-agent ${timeout:+-t"$timeout"} ||                \
				return ${FAILURE:-1}                         \
		fi                                                           \
	fi                                                                   \
	ps -p "$SSH_AGENT_PID" || return ${FAILURE:-1}                       \
	local suffix file show= load_required=                               \
	[ $# -eq 0 ] && load_required=1                                      \
	for suffix in "$@"; do                                               \
		file="/mnt/keys/id_rsa.$suffix"                              \
		ssh-add -l | awk -v file="$file" '\''                       \\
			gsub(/(^[0-9]+ [[:xdigit:]:]+ | \(.*\).*$)/, "") && \\
				$0 == file { exit found++ }                 \\
			END { exit \!found }                                \\
		'\'' && show="$show${show:+|}$suffix" &&                     \
	                continue # already loaded                            \
		load_required=1                                              \
		break                                                        \
	done                                                                 \
	ssh-add -l | colorize -c 36 "/mnt/keys/id_rsa\\.($show)([[:space:]]|$)" \
	[ "$load_required" ] || return ${SUCCESS:-0}                         \
	openkey ${verbose:+-v} || return ${FAILURE:-1}                       \
	[ "$verbose" ] && ssh-add -l                                         \
	local loaded_new=                                                    \
	if [ $# -gt 0 ]; then                                                \
		for suffix in "$@"; do                                       \
			file="/mnt/keys/id_rsa.$suffix"                      \
			[ -f "$file" ] || continue                           \
			ssh-add -l | awk -v file="$file" '\''               \\
				gsub(/(^[0-9]+ [[:xdigit:]:]+ | \(.*\).*$)/,\\
					"") && $0 == file { exit found++ }  \\
				END { exit \!found }                        \\
			'\'' && continue                                     \
			ssh-add "$file" || continue                          \
			loaded_new=1                                         \
			show="$show${show:+|}$suffix"                        \
		done                                                         \
	else                                                                 \
		for file in /mnt/keys/id_rsa.*; do                           \
			[ -e "$file" ] || continue                           \
			[ "$file" != "${file%.[Pp][Uu][Bb]}" ] && continue   \
			ssh-add -l | awk -v file="$file" '\''               \\
				gsub(/(^[0-9]+ [[:xdigit:]:]+ | \(.*\).*$)/,\\
					"") && $0 == file { exit found++ }  \\
				END { exit \!found }                         \
			'\'' && continue                                     \
			ssh-add "$file" || continue                          \
			loaded_new=1                                         \
			show="$show${show:+|}${file#/mnt/keys/id_rsa.}"      \
		done                                                         \
	fi                                                                   \
	[ "$close" ] && closekey ${verbose:+-v} ${eject:+-e}                 \
	[ "$loaded_new" ] && ssh-add -l |                                    \
		colorize -c 36 "/mnt/keys/id_rsa\\.($show)([[:space:]]|$)"   \
'

# unloadkeys [OPTIONS] [key ...]
#
# Unload my SSH private keys from my F.o thumb. The `key' argument is to the
# SSH private keyfile's suffix; in example, "sf" for "id_rsa.sf" or "f.o" for
# "id_rsa.f.o" or "gh" for "id_rsa.gh".
#
# For example, to unload the Sourceforge.net key, F.o key, and Github key:
# 	unloadkeys sf f.o gh
#
# OPTIONS:
# 	-a           Unload all keys.
# 	-c           Close USB media after unloading keys.
# 	-e           Close and eject USB media after unloading keys.
# 	-h           Print this text to stderr and return.
# 	-v           Print verbose debugging information.
#
# NB: Requires closekey() colorize() eprintf() openkey() quietly()
#     -- from this file
# NB: Requires awk(1) ps(1) ssh-add(1) -- from base system
#
quietly unalias unloadkeys
shfunction unloadkeys \
	'__fprintf=$shfunc_fprintf:q' \
	'__eprintf=$shfunc_eprintf:q' \
	'__openkey=$shfunc_openkey:q' \
	'__quietly=$shfunc_quietly:q' \
	'__colorize=$shfunc_colorize:q' \
	'__closekey=$shfunc_closekey:q' \
'                                                                            \
	eval "$__fprintf"                                                    \
	eval "$__eprintf"                                                    \
	eval "$__openkey"                                                    \
	eval "$__quietly"                                                    \
	eval "$__colorize"                                                   \
	eval "$__closekey"                                                   \
	local OPTIND=1 OPTARG flag all= close= eject= verbose=               \
	while getopts acehv flag; do                                         \
		case "$flag" in                                              \
		a) all=1 ;;                                                  \
		c) close=1 ;;                                                \
		e) close=1 eject=1 ;;                                        \
		v) verbose=1 ;;                                              \
		*) local optfmt="\t%-12s %s\n"                               \
		   eprintf "Usage: $FUNCNAME [OPTIONS] [key ...]\n"          \
		   eprintf "OPTIONS:\n"                                      \
		   eprintf "$optfmt" "-a" "Unload all keys."                 \
		   eprintf "$optfmt" "-c"                                \\\\\
		           "Close USB media after loading keys."             \
		   eprintf "$optfmt" "-e"                                \\\\\
		           "Close and eject USB media after loading keys."   \
		   eprintf "$optfmt" "-h"                                \\\\\
		           "Print this text to stderr and return."           \
		   eprintf "$optfmt" "-v"                                \\\\\
		           "Print verbose debugging information."            \
		   return ${FAILURE:-1}                                      \
		esac                                                         \
	done                                                                 \
	shift $(( $OPTIND - 1 ))                                             \
	local suffix file show= unload_required=                             \
	if [ "$all" ]; then                                                  \
		unload_required=1                                            \
		shift $#                                                     \
	fi                                                                   \
	for suffix in "$@"; do                                               \
		file="/mnt/keys/id_rsa.$suffix"                              \
		ssh-add -l | awk -v file="$file" '\''                       \\
			gsub(/(^[0-9]+ [[:xdigit:]:]+ | \(.*\).*$)/, "") && \\
				$0 == file { exit found++ }                 \\
			END { exit \!found }                                \\
		'\'' || continue # not loaded                                \
		show="$show${show:+|}$suffix"                                \
		unload_required=1                                            \
		break                                                        \
	done                                                                 \
	ssh-add -l | colorize -c 31 "/mnt/keys/id_rsa\\.($show)([[:space:]]|$)" \
	[ "$unload_required" ] || return ${SUCCESS:-0}                       \
	openkey ${verbose:+-v} || return ${FAILURE:-1}                       \
	[ "$verbose" ] && ssh-add -l                                         \
	if [ "$all" ]; then                                                  \
		ssh-add -D                                                   \
	else                                                                 \
		for suffix in "$@"; do                                       \
			file="/mnt/keys/id_rsa.$suffix"                      \
			[ -f "$file" ] || continue                           \
			ssh-add -l | awk -v file="$file" '\''               \\
				gsub(/(^[0-9]+ [[:xdigit:]:]+ | \(.*\).*$)/,\\
					"") && $0 == file { exit found++ }  \\
				END { exit \!found }                        \\
			'\'' || continue                                     \
			ssh-add -d "$file"                                   \
		done                                                         \
	fi                                                                   \
	[ "$close" ] && closekey ${verbose:+-v} ${eject:+-e}                 \
	[ "$all" ] || ssh-add -l |                                           \
		colorize -c 36 "/mnt/keys/id_rsa\\.($show)([[:space:]]|$)"   \
'

# dialog_menutag
#
# Obtain the menutag chosen by the user from the most recently displayed
# dialog(1) menu and clean up any temporary files.
#
# NB: Requires quietly() -- from this file
# NB: Requires $DIALOG_TMPDIR -- from this file
# NB: Requires rm(1) -- from base system
#
quietly unalias dialog_menutag
shfunction dialog_menutag \
	'__quietly=$shfunc_quietly:q' \
'                                                                            \
	eval "$__quietly"                                                    \
	local tmpfile="$DIALOG_TMPDIR/dialog.menu.$$"                        \
                                                                             \
	[ -f "$tmpfile" ] || return ${FAILURE:-1}                            \
                                                                             \
	cat "$tmpfile" 2> /dev/null                                          \
	quietly rm -f "$tmpfile"                                             \
                                                                             \
	return ${SUCCESS:-0}                                                 \
'

# dialog_menutag2help $tag_chosen $tag1 $item1 $help1 \
#                                 $tag2 $item2 $help2
#
# To use the `--menu' option of dialog(1) with the `--item-help' option, you
# must pass an ordered list of tag/item/help triplets on the command-line. When
# the user selects a menu option the tag for that item is printed to stderr.
#
# This function allows you to dereference the tag chosen by the user back into
# the help associated with said tag (item is discarded/ignored).
#
# Pass the tag chosen by the user as the first argument, followed by the
# ordered list of tag/item/help triplets (HINT: use the same tag/item/help list
# as was passed to dialog(1) for consistency).
#
# If the tag cannot be found, NULL is returned.
#
quietly unalias dialog_menutag2help
shfunction dialog_menutag2help '                                             \
	local tag="$1" tagn help                                             \
	shift 1 # tag                                                        \
                                                                             \
	while [ $# -gt 0 ]; do                                               \
		tagn="$1"                                                    \
		help="$3"                                                    \
		shift 3 # tagn/item/help                                     \
                                                                             \
		if [ "$tag" = "$tagn" ]; then                                \
			echo "$help"                                         \
			return ${SUCCESS:-0}                                 \
		fi                                                           \
	done                                                                 \
	return ${FAILURE:-1}                                                 \
'

# colorize [-c ANSI] [-e ANSI] pattern
#
# Colorize text matching pattern with ANSI sequence (default is `31;1' for red-
# bold). Non-matching lines are printed as-is.
#
# NB: Requires awk(1) -- from base system
#
quietly unalias colorize
shfunction colorize '                                                        \
	local OPTIND=1 OPTARG flag                                           \
	local ti=                                                            \
	local te=                                                            \
	while getopts c:e: flag; do                                          \
		case "$flag" in                                              \
		c) ti="$OPTARG" ;;                                           \
		e) te="$OPTARG" ;;                                           \
		esac                                                         \
	done                                                                 \
	shift $(( $OPTIND - 1 ))                                             \
                                                                             \
	awk -v ti="${ti:-31;1}" -v te="${te:-39;22}" -v pattern="$1" '\''    \
		gsub(pattern, "\033[" ti "m&\033[" te "m")||1                \
	'\'' # END-QUOTE                                                     \
'

############################################################ MISCELLANEOUS

#
# Override the default password prompt for sudo(8). This helps differentiate
# the sudo(8) password prompt from others such as su(1), ssh(1), and login(1).
#
setenv SUDO_PROMPT '[sudo] Password:'

#
# Quietly attach to running ssh-agent(1) unless agent already given
#
if ( ! $?SSH_AUTH_SOCK ) then
	if ( "$interactive" ) then
		ssh-agent-dup
	else
		quietly ssh-agent-dup -n || :
	endif
endif

################################################################################
# END
################################################################################
