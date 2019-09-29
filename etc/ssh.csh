# -*- tab-width:  4 -*- ;; Emacs
# vi: set tabstop=8     :: Vi/ViM
############################################################ IDENT(1)
#
# $Title: csh(1) semi-subroutine file $
# $Copyright: 2015-2019 Devin Teske. All rights reserved. $
# $FrauBSD: //github.com/FrauBSD/secure_thumb/etc/ssh.csh 2019-09-29 15:30:46 -0700 freebsdfrau $
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
# NB: Required by escape alias
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
		gsub(/ /,a "\\ " a)                                         \\
		gsub(/\t/,a "$tab:q" a)                                     \\
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
	eval alias $__name "'\''set $__argv = (\\\!*);'\''"\$__body:q        \
	unset $__alias                                                       \
	set $__alias = $__body:q                                             \
'
quietly unalias function
alias function "set argv_function = (\!*); "$alias_function:q

############################################################ FUNCTIONS

# cmdsubst $var [$env] $cmd
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

# evalsubst [$env] $cmd
#
# Execute $cmd via /bin/sh and evaluate the results.
# Like "set $var = `env $env /bin/sh -c $cmd:q`" except output is preserved.
#
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
# NB: There must be a literal newline or semi-colon at the end.
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
	set __body = "$__name(){ local FUNCNAME=$__name; $__body:q }"        \
	set $__func = $__body:q                                              \
	set $__alias = $__body:q\;\ $__name\ \"\$@\"                         \
	have $__name || eval alias $__name "'\''$__interp /bin/sh'\''"       \
'

# eshfunction $name $code
#
# Define a ``function'' that runs under /bin/sh but produces output that is
# evaluated in the current shell's namespace.
#
# NB: There must be a literal newline or semi-colon at the end.
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
	set __interp = "$__penv:q "\"\$"${__alias}:q"\"                      \
	set __body = "$__name(){ local FUNCNAME=$__name; $__body:q }"        \
	set $__func = $__body:q                                              \
	set $__alias = $__body:q\;\ $__name\ \"\$@\"                         \
	have $__name || eval alias $__name "evalsubst '\''$__interp'\''"     \
'

# quietly $cmd ...
#
# Execute /bin/sh $cmd while sending stdout and stderr to /dev/null.
#
shfunction quietly '"$@" > /dev/null 2>&1;'

# have name
#
# Silently test for name as an available command, builtin, or other executable.
#
shfunction have 'type "$@" > /dev/null 2>&1;'

# eval2 $cmd ...
#
# Print $cmd on stdout before executing it. 
#
shfunction eval2 'echo "$*"; eval "$@";'

# fprintf $fd $fmt [ $opts ... ]
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

# eprintf $fmt [ $opts ... ]
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
# NB: Requires dialog_menutag() dialog_menutag2help() eval2() have()
#     -- from this file
# NB: Requires $DIALOG_TMPDIR $DIALOG_MENU_TAGS -- from this file
# NB: Requires awk(1) cat(1) grep(1) id(1) ls(1) ps(1) ssh-add(1) stat(1)
#     -- from base system
#
#?quietly unalias ssh-agent-dup
#?shfunction ssh-agent-dup '                                                 \
#?	: XXX TODO XXX                                                       \
#?'

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
		   eprintf "$optfmt" "-h" \                                  \
		           "Print this text to stderr and return."           \
		   eprintf "$optfmt" "-v" \                                  \
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
#?quietly unalias closekey
#?shfunction closekey '                                                      \
#?	: XXX TODO XXX                                                       \
#?'

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
#?quietly unalias loadkeys
#?shfunction loadkeys '                                                      \
#?	: XXX TODO XXX                                                       \
#?'

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
#?quietly unalias unloadkeys
#?shfunction unloadkeys '                                                    \
#?	: XXX TODO XXX                                                       \
#?'

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
