#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to unmount GELI partitions of USB device $
# $Copyright: 2015-2018 Devin Teske. All rights reserved. $
# $Header: /cvsroot/druidbsd/secure_thumb/mount.sh,v 1.2 2015/09/08 19:53:31 devinteske Exp $
# $FrauBSD: secure_thumb/src/mount.sh 2018-11-08 11:58:27 -0800 freebsdfrau $
#
############################################################ CONFIGURATION

PARTS="s1d=keys s1e=encstore"

############################################################ GLOBALS

#
# Global exit status
#
SUCCESS=0
FAILURE=1

#
# Options
#
NO_DIALOG=	# -d
READ_STDIN=	# -S
VERBOSE=	# -v

############################################################ FUNCTIONS

have(){ type "$@" > /dev/null 2>&1; }
eval2(){ [ "$VERBOSE" ] && echo "$*"; eval "$@"; }

LOGGER_WARNED=
logger_check()
{
	local warning='!!! WARNING !!!'
	local caution='is loaded!\nAn attacker could snoop your password!'
	local logger=

	[ "$LOGGER_WARNED" ] && return $SUCCESS
	LOGGER_WARNED=1

	#
	# Check for keystroke logging engines
	#
	kldstat -v 2> /dev/null | grep -q dtrace && logger=DTrace

	#
	# Warn the user if a keystroke logger/engine was detected
	#
	if [ "$logger" ]; then
		if [ "$NO_DIALOG" ]; then
			printf "\033[33m%s\033[m %s $caution\n" \
				"$warning" "$logger"
			read -p "OK to proceed? [N]: " yesno
			case "$yesno" in
			[Yy]|[Yy][Ee][Ss]) : ok ;;
			*) return $FAILURE
			esac
		else dialog \
			--title "$warning" \
			--backtitle "$0" \
			--defaultno \
			--yesno "$logger $caution\nOK to proceed?" \
			7 43 || return $FAILURE	
		fi
	fi

	return $SUCCESS
}

mounted()
{
	local OPTIND=1 OPTARG flag device=
	while getopts d flag; do
		case "$flag" in
		d) device=1 ;;
		esac
	done
	shift $(( $OPTIND - 1 ))
	if [ "$device" ]; then
		mount | awk -v device="$1" '
			sub(/ on .*$/, "") && $0 == device {
				exit found++
			} END { exit !found }
		' # END-QUOTE
	else
		mount | awk -v dir="$1" '
			gsub(/(^.* on | \(.*\).*$)/, "") && $0 == dir {
				exit found++
			} END { exit !found }
		' # END-QUOTE
	fi
}

usage()
{
	local optfmt="\t%-4s %s\n"
	exec >&2
	printf "Usage: %s [-dhSv] daN\n" "$0"
	printf "OPTIONS:\n"
	printf "$optfmt" "-d" "Don't use dialog(1) to prompt for passphrase."
	printf "$optfmt" "-h" "Print this text to stderr and exit."
	printf "$optfmt" "-S" "Read passphrase from standard input."
	printf "$optfmt" "-v" "Print verbose debugging information."
	exit $FAILURE
}

############################################################ MAIN

while getopts dhSv flag; do
	case "$flag" in
	d) NO_DIALOG=1 ;;
	S) READ_STDIN=1 ;;
	v) VERBOSE=1 ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))

daN="$1"
BASE=$( realpath "$0" )
BASE="${BASE%/*}"

[ "$daN" ] || daN=$( df -l "$BASE" | awk '
	match($0, "^/dev/[[:alpha:]]+[[:digit:]]+") {
		print substr($0, 6, RLENGTH - 5)
		exit found++
	} END { exit !found }
' ) || usage

#
# Exit if all parts are mounted
#
all_mounted=1
for part in $PARTS; do
	mounted -d /dev/$daN${part%%=*}.eli && continue
	all_mounted=
	break
done
[ "$all_mounted" ] && exit $SUCCESS

#
# Run as non-root with sr or sudo
#
if [ "$( id -u )" != "0" ]; then
	if have sr; then
		sudo=sr
	elif have sudo; then
		sudo=sudo
	else
		echo "Must be root!" >&2
		exit $FAILURE
	fi
fi

#
# Get the device UUID
#
UUID_FILE="${0%/*}/.uuid"
if [ ! -e "$UUID_FILE" ]; then
	echo "$UUID_FILE: No such file or directory" >&2
	echo "Exiting!" >&2
	exit $FAILURE
elif [ -d "$UUID_FILE" ]; then
	echo "$UUID_FILE: Is a directory" >&2
	echo "Exiting!" >&2
	exit $FAILURE
elif ! UUID=$( head -1 "$UUID_FILE" ); then
	echo "Exiting!" >&2
	exit $FAILURE
fi

#
# Attach if necessary
#
exec 3>&1; PASSPHRASE=
[ "$READ_STDIN" ] && read PASSPHRASE
for part in $PARTS; do
	part="${part%%=*}"
	nodekey=${0%/*}/geli/ffthumb-$part.key
	hostkey=
	if [ "$GELI_HOST_KEY_DIR" ]; then
		hostkey=$GELI_HOST_KEY_DIR/ffhost-$UUID-$part.key
		[ ! -d "$hostkey" ] || [ -e "$hostkey" ] || hostkey=
	fi
	if [ ! "$hostkey" ]; then
		hostkey=~/geli/ffhost-$UUID-$part.key
		[ ! -d "$hostkey" ] || [ -e "$hostkey" ] || hostkey=
	fi
	if [ ! "$hostkey" ]; then
		echo "No host key for $part partition (skipping)" >&2
		continue
	fi
	if ! geli status $daN$part.eli 2> /dev/null; then
		logger_check || exit $FAILURE
		[ "$PASSPHRASE" -o "$READ_STDIN" ] || PASSPHRASE=$(
			[ ! "$NO_DIALOG" ] && dialog \
				--title "geli attach $daN" --backtitle "$0" \
				--hline "Keys will not appear as you type" \
				--passwordbox "Enter passphrase:" 8 45 2>&1 >&3
		) || PASSPHRASE=$(
			trap "stty echo" EXIT
			stty -echo
			read -p "[GELI] Passphrase:" PASSPHRASE >&3
			result=$?
			trap - EXIT
			stty echo
			echo >&3
			echo "$PASSPHRASE"
			[ $result -eq 0 ]
		) || exit $FAILURE
		echo "$PASSPHRASE" | eval2 $sudo geli attach -j- \
			-k "$nodekey" -k "$hostkey" $daN$part || exit $FAILURE
		geli status $daN$part.eli || exit $FAILURE
	fi
done

#
# Mount if necessary
#
for part in $PARTS; do
	part="${part%%=*}" mnt="${part#*=}"
	geli status $daN$part.eli > /dev/null 2>&1 || continue
	mounted "$BASE/$mnt" && continue
	eval2 $sudo mount /dev/$daN$part.eli "$BASE/$mnt" || exit $FAILURE
done

exit $SUCCESS

################################################################################
# END
################################################################################
