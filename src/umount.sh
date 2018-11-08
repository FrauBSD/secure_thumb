#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to mount GELI partitions of USB device $
# $Copyright: 2015-2018 Devin Teske. All rights reserved. $
# $Header: /cvsroot/druidbsd/secure_thumb/umount.sh,v 1.2 2015/09/08 19:53:31 devinteske Exp $
# $FrauBSD: secure_thumb/src/umount.sh 2018-11-08 11:58:27 -0800 freebsdfrau $
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
VERBOSE=	# -v

############################################################ FUNCTIONS

have(){ type "$@" > /dev/null 2>&1; }
eval2(){ [ "$VERBOSE" ] && echo "$*"; eval "$@"; }

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
	printf "Usage: %s [-hv] daN\n" "$0"
	printf "OPTIONS:\n"
	printf "$optfmt" "-h" "Print this text to stderr and exit."
	printf "$optfmt" "-v" "Print verbose debugging information."
	exit $FAILURE
}

############################################################ MAIN

while getopts hv flag; do
	case "$flag" in
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
# Unmount if necessary
#
for part in $PARTS; do
	part="${part%%=*}" mnt="${part#*=}"
	mounted "$BASE/$mnt" || continue
	eval2 $sudo umount "$BASE/$mnt" || exit $FAILURE
done

#
# Dettach if necessary
#
for part in $PARTS; do
	part="${part%%=*}"
	geli status $daN$part.eli > /dev/null 2>&1 || continue
	eval2 $sudo geli detach $daN$part || exit $FAILURE
done

exit $SUCCESS

################################################################################
# END
################################################################################
