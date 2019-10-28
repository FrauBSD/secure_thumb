############################################################ IDENT(1)
#
# $Title: Makefile to produce GELI encrypted image for use on USB thumb drive $
# $Copyright: 2018 Devin Teske. All rights reserved. $
# $FrauBSD: //github.com/FrauBSD/secure_thumb/Makefile 2019-10-28 14:23:14 +0000 freebsdfrau $
#
############################################################ OBJECTS

# Image file
IMGFILE=	secure_thumb.md

# Sizes (in MB)
IMGSIZE=	256

# Sizes (in KB)
KEYSIZE=	512

# Entropy source
RANDOM=		/dev/random

# Filesystem settings
NEWFS_ARGS=	-n -U -O 1 -f 512 -b 4096 -i 8192

############################################################ FUNCTIONS

EVAL2=		exec 3<&1; eval2(){ echo "$$*" >&3;eval "$$*"; }

MOUNTED=	\
	mounted()                                                      \
	{                                                              \
		local OPTIND=1 OPTARG flag quiet=;                     \
		while getopts q flag; do                               \
			case "$$flag" in                               \
			q) quiet=1 ;;                                  \
			esac;                                          \
		done;                                                  \
		shift $$(( $$OPTIND - 1 ));                            \
		local df dev=$$1 dir=$$2;                              \
		local _awk="'\$$1==\"$$dev\"{exit s=1}END{exit !s}'";  \
		if [ "$$quiet" ]; then                                 \
			df -nh $$dir | eval awk -v dev=$$dev "$$_awk"; \
		else                                                   \
			df=$$( eval2 df -nh $$dir );                   \
			echo "$$df";                                   \
			echo "$$df" | eval2 awk -v dev=$$dev "$$_awk"; \
		fi;                                                    \
	}

MOUNTDEV=	\
	mountdev()                                                    \
	{                                                             \
		local OPTIND=1 OPTARG flag quiet=;                    \
		while getopts q flag; do                              \
			case "$$flag" in                              \
			q) quiet=1 ;;                                 \
			esac;                                         \
		done;                                                 \
		shift $$(( $$OPTIND - 1 ));                           \
		local df dir="$$1";                                   \
		local _awk="'NR>1{print \$$1;exit s=1}END{exit !s}'"; \
		if [ "$$quiet" ]; then                                \
			df -nh $$dir | eval awk "$$_awk";             \
		else                                                  \
			df=$$( eval2 df -nh $$dir );                  \
			echo "$$df";                                  \
			echo "$$df" | eval2 awk "$$_awk";             \
		fi;                                                   \
	}

DISKPROMPT=	\
	diskprompt()                                                         \
	{                                                                    \
		DISK=;                                                       \
		local disks ndisks ignored _new d n num;                     \
		disks=$$( sysctl -n kern.disks );                            \
		set -- $$disks;                                              \
		ndisks=$$\#;                                                 \
		while :; do                                                  \
			printf "< Insert physical media and press ENTER > "; \
			read ignored;                                        \
			set -- $$( sysctl -n kern.disks );                   \
			if [ $$\# -lt $$ndisks ]; then                       \
				disks="$$*";                                 \
				ndisks=$$\#;                                 \
				continue;                                    \
			elif [ "$$*" = "$$disks" ]; then                     \
				continue;                                    \
			fi;                                                  \
			break;                                               \
		done;                                                        \
		_new=;                                                       \
		for d in $$*; do                                             \
			case "$$disks" in                                    \
			"$$d"|"$$d "*|*" $$d") continue ;;                   \
			esac;                                                \
			_new="$$_new $$d";                                   \
		done;                                                        \
		set -- $$_new;                                               \
		if [ $$\# -gt 1 ]; then                                      \
			n=1;                                                 \
			while :; do                                          \
				echo "Detected disks:";                      \
				for d in $$*; do                             \
					printf "\t%u) %s\n" $$n $$d;         \
					n=$$(( $$n + 1 ));                   \
				done;                                        \
				printf "Choose disk: ";                      \
				read num;                                    \
				eval set -- \$$$${num};                      \
				[ ! "$$1" ] && break;                        \
			done;                                                \
		fi;                                                          \
		DISK="$$1";                                                  \
	}

YESNO=	\
	yesno()                                       \
	{                                             \
		local OPTIND=1 OPTARG flag;           \
		local default_no=;                    \
		while getopts n flag; do              \
			case "$$flag" in              \
			n) default_no=1 ;;            \
			esac;                         \
		done;                                 \
		shift $$(( $$OPTIND - 1 ));           \
		local yesno= prompt="$$*";            \
		while [ ! "$$yesno" ]; do             \
			printf "$$prompt";            \
			read yesno;                   \
			[ ! "$$yesno" ] &&            \
				[ "$$default_no" ] && \
				break;                \
		done;                                 \
		case "$$yesno" in                     \
		[Yy]|[Yy][Ee][Ss]) return 0 ;;        \
		esac;                                 \
		echo "User cancelled (exiting)" >&2;  \
		exit 0;                               \
	}

DD_WITH_PROGRESS=	\
	dd_with_progress()                                                    \
	{                                                                     \
		local arg infile=;                                            \
		for arg in "$$@"; do                                          \
			case "$$arg" in                                       \
			if=*) infile="$${arg\#if=}"; break ;;                 \
			esac;                                                 \
		done;                                                         \
		if [ ! "$$infile" ]; then                                     \
			echo "dd_with_progress: No input file (exiting)" >&2; \
			exit 1;                                               \
		fi;                                                           \
		sudo -v || exit 1;                                            \
		trap exit SIGINT;                                             \
		( eval "eval2 sudo dd $$* 2>&1 &";                            \
			local sudo_pid=$$! dd_pid=;                           \
			while [ ! "$$dd_pid" ]; do                            \
				dd_pid=$$( sudo ps axo pid,ppid |             \
					awk -v ppid="$$sudo_pid"              \
						'$$2==ppid{print $$1}' );     \
				sleep 1;                                      \
			done;                                                 \
			while sudo kill -INFO $$dd_pid > /dev/null 2>&1; do   \
				sleep 1;                                      \
			done;                                                 \
		) | time awk -v total="$$( stat -f%z "$$infile" )" '          \
			BEGIN {                                               \
				w = 40;                                       \
				bar = sprintf("[%*s] (%3s%%)", w, "", "");    \
				ln = "%10.1f MB [%s%*s] (%3u%%) %10.1f MB/s"; \
			}                                                     \
			/bytes transferred/ {                                 \
				pct = $$1 * 100 / total;                      \
				left = int(w * pct / 100);                    \
				right = w - left;                             \
				bar = sprintf("%*s", left, "");               \
				gsub(/ /, "=", bar);                          \
				sub(/.$$/, ">", bar);                         \
				rate = $$(NF-1);                              \
				sub(/^\(/, "", rate);                         \
				printf "\r" ln, $$1 / 1024 / 1024, bar,       \
					right, "", pct, rate / 1024 / 1024;   \
				fflush();                                     \
			}                                                     \
			END { print "" }                                      \
		';                                                            \
	}

############################################################ TARGETS

$(IMGFILE):
	dd if=/dev/zero of=$(IMGFILE) bs=1m seek=$(IMGSIZE) count=0
	@$(EVAL2);                                                           \
	 $(YESNO);                                                           \
	 set -e;                                                             \
	 trap='eval2 sudo mdconfig -d -u "$${md#md}"';                       \
	 trap "$$trap" EXIT;                                                 \
	 md=$$( eval2 sudo mdconfig -f $(IMGFILE) );                         \
	 echo "$$md";                                                        \
	 md="$${md%%[$$IFS]*}";                                              \
	 eval2 sudo gpart create -s MBR "$$md";                              \
	 eval2 sudo gpart add -t freebsd -i 1 "$$md";                        \
	 eval2 sudo gpart create -s BSD "$${md}s1";                          \
	 eval2 sudo gpart add -t freebsd-ufs -i 1 -s 128m "$${md}s1";        \
	 eval2 sudo gpart add -t freebsd-ufs -i 4 -s 16m "$${md}s1";         \
	 eval2 sudo gpart add -t freebsd-ufs -i 5 "$${md}s1";                \
	 eval2 sudo newfs $(NEWFS_ARGS) "$${md}s1a";                         \
	 eval2 mkdir -p mnt;                                                 \
	 eval2 sudo mount "/dev/$${md}s1a" mnt;                              \
	 trap="eval2 sudo umount mnt && ( eval2 rmdir mnt || : ) && $$trap"; \
	 trap "$$trap" EXIT;                                                 \
	 eval2 sudo mkdir -m 0700 -p mnt/geli;                               \
	 logger=;                                                            \
	 caution='is loaded!\nAn attacker could snoop your password!';       \
	 kldstat -v 2> /dev/null | grep -q dtrace && logger=DTrace;          \
	 if [ "$$logger" ]; then                                             \
	 	trap "$$trap && eval2 rm -f $(IMGFILE)" EXIT;                \
	 	printf "\033[33m!!! WARNING !!!\033[m $$logger $$caution\n"; \
	 	trap echo SIGINT;                                            \
	 	yesno -n "OK to proceed? [N]: ";                             \
	 	trap - SIGINT;                                               \
	 	trap "$$trap" EXIT;                                          \
	 fi;                                                                 \
	 trap "stty echo || :; $$trap" EXIT;                                 \
	 trap echo SIGINT;                                                   \
	 stty -echo;                                                         \
	 printf "Enter new passphrase: ";                                    \
	 read pass1;                                                         \
	 echo;                                                               \
	 printf "Reenter new passphrase: ";                                  \
	 read pass2;                                                         \
	 echo;                                                               \
	 stty echo;                                                          \
	 trap - SIGINT;                                                      \
	 trap "$$trap" EXIT;                                                 \
	 if [ "$$pass1" != "$$pass2" ]; then                                 \
	 	echo "Password mismatch (exiting)" >&2;                      \
	 	trap "$$trap && eval2 rm -f $(IMGFILE)" EXIT;                \
	 	exit 1;                                                      \
	 fi;                                                                 \
	 eval2 sudo uuidgen -o mnt/.uuid;                                    \
	 eval2 sudo chmod 444 mnt/.uuid;                                     \
	 eval2 sudo chflags schg mnt/.uuid;                                  \
	 uuid=$$( eval2 cat mnt/.uuid );                                     \
	 echo "$$uuid";                                                      \
	 gelipart1=s1d;                                                      \
	 gelinode1=mnt/geli/ffthumb-$$gelipart1;                             \
	 gelihost1=geli/ffhost-$$uuid-$$gelipart1;                           \
	 gelipart2=s1e;                                                      \
	 gelinode2=mnt/geli/ffthumb-$$gelipart2;                             \
	 gelihost2=geli/ffhost-$$uuid-$$gelipart2;                           \
	 eval2 mkdir -m 0700 -p geli;                                        \
	 for num in 1 2; do                                                  \
	 	eval node=\$$gelinode$$num;                                  \
	 	eval host=\$$gelihost$$num;                                  \
	 	eval part=\$$gelipart$$num;                                  \
	 	eval2 sudo dd if=$(RANDOM) of=$$node.key                     \
	 		bs=1k count=$(KEYSIZE);                              \
	 	eval2 dd if=$(RANDOM) of=$$host.key                          \
	 		bs=1k count=$(KEYSIZE);                              \
	 	eval2 sudo chmod 400 $$node.key;                             \
	 	eval2 sudo chflags schg $$node.key;                          \
	 	eval2 chmod 400 $$host.key;                                  \
	 	echo "$$pass1" | eval2 sudo geli init -J- -B $$node.backup   \
	 		-K $$node.key -K $$host.key $$md$$part;              \
	 	echo "$$pass1" | eval2 sudo geli attach -j-                  \
	 		-k $$node.key -k $$host.key $$md$$part;              \
	 	trap="eval2 sudo geli detach $$md$$part && $$trap";          \
	 	trap "$$trap" EXIT;                                          \
	 	eval2 sudo newfs $(NEWFS_ARGS) $$md$$part.eli;               \
	 done;                                                               \
	 eval2 sudo mkdir -m 0700 -p mnt/keys;                               \
	 eval2 sudo mount "/dev/$${md}s1d.eli" mnt/keys;                     \
	 trap="eval2 sudo umount mnt/keys && $$trap";                        \
	 trap "$$trap" EXIT;                                                 \
	 eval2 sudo mkdir -m 0700 -p mnt/encstore;                           \
	 if eval2 type rsync > /dev/null 2>&1; then                          \
	 	eval2 sudo rsync -avSH src/ mnt/;                            \
	 else                                                                \
	 	dirs=$$( eval2 find src/ -mindepth 1 -type d ! -name CVS );  \
	 	echo "$$dirs";                                               \
	 	echo "$$dirs" | eval2 sed -e "'s/^src/mnt/'" |               \
	 		eval2 sudo xargs mkdir -pv;                          \
	 	files=$$( eval2 find src/ -type f ! -path "'*/CVS/*'" );     \
	 	echo "$$files";                                              \
	 	echo "$$files" |                                             \
	 		eval2 sed -e "'s/^src//;s/.*/src& mnt&/'" |          \
	 		eval2 sudo xargs -n2 cp -av;                         \
	 fi;                                                                 \
	 eval2 sudo chmod 555 mnt/mount.sh mnt/umount.sh;                    \
	 eval2 sudo chflags schg mnt/mount.sh mnt/umount.sh

.PHONY: all

all: $(IMGFILE)

.PHONY: usage help

usage:
	@exec >&2;                                                          \
	 echo "Targets:";                                                   \
	 echo " all (default):   Create $(IMGFILE)";                        \
	 echo " install:         Copy etc/ssh.subr to ~/etc/";              \
	 echo " status:          Show attach/mount status";                 \
	 echo " open:            Attach and mount $(IMGFILE)";              \
	 echo " close:           Unmount and detach $(IMGFILE)";            \
	 echo " attach:          Attach an md(4) device to $(IMGFILE)";     \
	 echo " detach:          Detach md(4) device from $(IMGFILE)";      \
	 echo " resize:          Resize $(IMGFILE) to IMGSIZE MB";          \
	 echo " deploy:          Write $(IMGFILE) to physical media";       \
	 echo " expand:          Resize physical media to use free space";  \
	 echo " synctousb:       Copy files from $(IMGFILE) to media";      \
	 echo " synctoimg:       Copy files from media to $(IMGFILE)";      \
	 echo

help: usage

.PHONY: attach open close detach

attach: $(IMGFILE)
	@$(EVAL2);                                                 \
	 set -e;                                                   \
	 if ! [ -e $(IMGFILE) ]; then                              \
	 	echo "$(IMGFILE) does not exist (exiting)" >&2;    \
	 	exit 1;                                            \
	 fi;                                                       \
	 if md=$$( eval2 sudo mdconfig -lf $(IMGFILE) ); then      \
	 	echo "$$md";                                       \
	 	echo "$(IMGFILE) already attached (skipping)" >&2; \
	 	exit 0;                                            \
	 fi;                                                       \
	 md=$$( eval2 sudo mdconfig -f $(IMGFILE) );               \
	 echo "$$md";                                              \
	 md="$${md%%[$$IFS]*}";                                    \
	 echo "$(IMGFILE) successfully attached to $$md" >&2

open: attach
	@$(EVAL2);                                                          \
	 $(MOUNTED);                                                        \
	 $(MOUNTDEV);                                                       \
	 set -e;                                                            \
	 md=$$( eval2 sudo mdconfig -lf $(IMGFILE) );                       \
	 echo "$$md";                                                       \
	 md="$${md%%[$$IFS]*}";                                             \
	 eval2 mkdir -p mnt;                                                \
	 dev="/dev/$${md}s1a";                                              \
	 if mounted "$$dev" mnt; then                                       \
	 	echo "$(IMGFILE) already mounted on mnt (skipping)" >&2;    \
	 else                                                               \
	 	dotdev=$$( mountdev . );                                    \
	 	mntdev=$$( mountdev mnt );                                  \
	 	if [ "$$mntdev" != "$$dotdev" ]; then                       \
	 		echo "Foreign device mounted on mnt (exiting)" >&2; \
	 		exit 1;                                             \
	 	fi;                                                         \
	 	eval2 sudo mount "$$dev" mnt;                               \
	 	echo "$(IMGFILE) successfully mounted on mnt" >&2;          \
	 fi;                                                                \
	 [ -e mnt/mount.sh ] || exit 0;                                     \
	 if ! eval2 GELI_HOST_KEY_DIR=./geli sh mnt/mount.sh -d; then       \
	 	echo "Mount failed! Use \`make close' to clean up" >&2;     \
	 	exit 1;                                                     \
	 fi

close:
	@$(EVAL2);                                                  \
	 $(MOUNTED);                                                \
	 set -e;                                                    \
	 [ -e $(IMGFILE) ] || exit 0;                               \
	 if ! md=$$( eval2 sudo mdconfig -lf $(IMGFILE) ); then     \
	 	echo "$(IMGFILE) not attached (skipping)" >&2;      \
	 	exit 0;                                             \
	 fi;                                                        \
	 echo "$$md";                                               \
	 md="$${md%%[$$IFS]*}";                                     \
	 if [ ! -e mnt ]; then                                      \
	 	eval2 sudo mdconfig -d -u "$${md#md}";              \
	 	exit 0;                                             \
	 fi;                                                        \
	 dev="/dev/$${md}s1a";                                      \
	 if mounted "$$dev" mnt; then                               \
	 	[ ! -e mnt/umount.sh ] || eval2 sh mnt/umount.sh;   \
	 	eval2 sudo umount mnt;                              \
	 fi;                                                        \
	 eval2 sudo mdconfig -d -u "$${md#md}";                     \
	 eval2 rmdir mnt || :;                                      \
	 echo "$(IMGFILE) successfully unmounted and detached" >&2

detach:
	@$(EVAL2);                                              \
	 set -e;                                                \
	 [ -e $(IMGFILE) ] || exit 0;                           \
	 if ! md=$$( eval2 sudo mdconfig -lf $(IMGFILE) ); then \
	 	echo "$(IMGFILE) not attached (skipping)" >&2;  \
	 	exit 0;                                         \
	 fi;                                                    \
	 echo "$$md";                                           \
	 md="$${md%%[$$IFS]*}";                                 \
	 eval2 sudo mdconfig -d -u "$${md#md}" &&               \
	 	echo "$$md successfully detached from $(IMGFILE)" >&2

.PHONY: deploy

deploy: $(IMGFILE)
	@$(EVAL2);                                                           \
	 $(DISKPROMPT);                                                      \
	 $(YESNO);                                                           \
	 $(DD_WITH_PROGRESS);                                                \
	 $(MOUNTED);                                                         \
	 set -e;                                                             \
	 if ! [ -e $(IMGFILE) ]; then                                        \
	 	echo "$(IMGFILE) does not exist (exiting)" >&2;              \
	 	exit 1;                                                      \
	 fi;                                                                 \
	 diskprompt;                                                         \
	 echo "LAST CHANCE!!! Will write $(IMGFILE) to /dev/$$DISK";         \
	 yesno "OK to overwrite any/all data on $$DISK? [y/n]: ";            \
	 dd_with_progress if=$(IMGFILE) of=/dev/$$DISK bs=1m;                \
	 trap=;                                                              \
	 if ! md=$$( eval2 sudo mdconfig -lf $(IMGFILE) 2> /dev/null ); then \
	 	if ! md=$$( eval2 sudo mdconfig -f $(IMGFILE) ); then        \
	 		echo "Unable to deploy host keys (exiting)" >&2;     \
	 		exit 1;                                              \
	 	fi;                                                          \
	 	echo "$$md";                                                 \
	 	md="$${md%%[$$IFS]*}";                                       \
	 	trap='eval2 sudo mdconfig -d -u $${md#md}';                  \
	 	trap "$$trap" EXIT;                                          \
	 else                                                                \
	 	echo "$$md";                                                 \
	 	md="$${md%%[$$IFS]*}";                                       \
	 fi;                                                                 \
	 if [ ! -e mnt ]; then                                               \
	 	eval2 mkdir -p mnt;                                          \
	 	trap="eval2 rmdir mnt && $$trap";                            \
	 	trap "$$trap" EXIT;                                          \
	 	eval2 sudo mount /dev/$${md}s1a mnt;                         \
	 	trap="eval2 sudo umount mnt && $$trap";                      \
	 	trap "$$trap" EXIT;                                          \
	 elif ! mounted /dev/$${md}s1a mnt; then                             \
	 	eval2 sudo mount /dev/$${md}s1a mnt;                         \
	 	trap="eval2 sudo umount mnt && $$trap";                      \
	 	trap "$$trap" EXIT;                                          \
	 fi;                                                                 \
	 uuid=$$( eval2 cat mnt/.uuid );                                     \
	 echo "$$uuid";                                                      \
	 trap - EXIT;                                                        \
	 eval "$$trap";                                                      \
	 eval2 mkdir -m 0700 -p ~/geli/;                                     \
	 eval2 cp -fav geli/ffhost-$$uuid-s*.key ~/geli/;                    \
	 echo "Success! $(IMGFILE) deployed and $$DISK is ready to use" >&2

.PHONY: resize expand

resize:
	@$(EVAL2);                                                          \
	 set -e;                                                            \
	 if [ ! -e $(IMGFILE) ]; then                                       \
	 	echo "$(IMGFILE) does not exist (skipping)" >&2;            \
	 	exit 0;                                                     \
	 fi;                                                                \
	 if eval2 sudo mdconfig -lf $(IMGFILE); then                        \
	 	echo "$(IMGFILE) attached (detaching)" >&2;                 \
	 	eval2 $(MAKE) IMGFILE=$(IMGFILE) close;                     \
	 fi;                                                                \
	 size=$$( eval2 stat -f%z $(IMGFILE) );                             \
	 echo "$$size";                                                     \
	 size=$$(( $$size / 1024 / 1024 ));                                 \
	 if [ $$size -eq $(IMGSIZE) ]; then                                 \
	 	echo "$(IMGFILE) is already $$size MB (exiting)" >&2;       \
	 	exit 0;                                                     \
	 elif [ $$size -gt $(IMGSIZE) ]; then                               \
	 	echo "Cannot shrink $(IMGFILE)"                             \
	 	     "from $$size to $(IMGSIZE) MB (exiting)" >&2;          \
	 	exit 1;                                                     \
	 fi;                                                                \
	 eval2 dd if=/dev/zero of=$(IMGFILE) bs=1m seek=$(IMGSIZE) count=0; \
	 eval2 $(MAKE) IMGFILE=$(IMGFILE) attach;                           \
	 trap 'eval2 $(MAKE) IMGFILE=$(IMGFILE) detach' EXIT;               \
	 if ! md=$$( eval2 sudo mdconfig -lf $(IMGFILE) ); then             \
	 	echo "$(IMGFILE) not attached (exiting)" >&2;               \
	 	exit 1;                                                     \
	 fi;                                                                \
	 echo "$$md";                                                       \
	 md="$${md%%[$$IFS]*}";                                             \
	 eval2 sudo gpart resize -i 1 "$$md";                               \
	 gpart=$$( eval2 gpart show "$${md}s1" );                           \
	 echo "$$gpart";                                                    \
	 oldsize=$$( echo "$$gpart" |                                       \
	 	eval2 awk "'\$$3==5{print \$$2*512}'" );                    \
	 echo "$$oldsize";                                                  \
	 eval2 sudo gpart resize -i 5 "$${md}s1";                           \
	 eval2 sudo geli resize -s $$oldsize "$${md}s1e";                   \
	 trap 'eval2 $(MAKE) IMGFILE=$(IMGFILE) close' EXIT;                \
	 eval2 $(MAKE) IMGFILE=$(IMGFILE) open;                             \
	 eval2 sudo growfs -y "$${md}s1e.eli"

expand:
	@$(EVAL2);                                                  \
	 $(DISKPROMPT);                                             \
	 $(YESNO);                                                  \
	 set -e;                                                    \
	 diskprompt;                                                \
	 echo "LAST CHANCE!!! Will resize /dev/$${DISK}s1e";        \
	 yesno "OK to expand partition to use free space? [y/n]: "; \
	 eval2 sudo gpart resize -i 1 $$DISK;                       \
	 gpart=$$( eval2 gpart show $${DISK}s1 );                   \
	 echo "$$gpart";                                            \
	 oldsize=$$( echo "$$gpart" |                               \
	 	eval2 awk "'\$$3==5{print \$$2*512}'" );            \
	 echo "$$oldsize";                                          \
	 eval2 sudo gpart resize -i 5 $${DISK}s1;                   \
	 eval2 sudo geli resize -s $$oldsize $${DISK}s1e;           \
	 eval2 mkdir -p mnt.usb;                                    \
	 trap="eval2 rmdir mnt.usb";                                \
	 trap "$$trap" EXIT;                                        \
	 eval2 sudo mount /dev/$${DISK}s1a mnt.usb;                 \
	 trap="eval2 sudo umount mnt.usb && $$trap";                \
	 trap "$$trap" EXIT;                                        \
	 eval2 env GELI_HOST_KEY_DIR=./geli sh mnt.usb/mount.sh -d; \
	 trap "eval2 sh mnt.usb/umount.sh && $$trap" EXIT;          \
	 eval2 sudo growfs -y $${DISK}s1e.eli

.PHONY: install

install:
	mkdir -p ~/etc
	cp etc/ssh.subr ~/etc/
	@echo 'Success!'
	@echo
	@echo 'Add to ~/.zprofile, ~/.bash_profile, or ~/.shrc'
	@echo
	@printf "\t. etc/ssh.subr\n"
	@echo
	@echo Add to /etc/fstab
	@echo
	@printf "\t/dev/da1s1a /mnt ufs rw,noauto 0 0\n"
	@echo

.PHONY: synctousb synctoimg

synctousb:
	@$(EVAL2);                                                      \
	 $(DISKPROMPT);                                                 \
	 set -e;                                                        \
	 if ! [ -e $(IMGFILE) ]; then                                   \
	 	echo "$(IMGFILE) does not exist (exiting)" >&2;         \
	 	exit 1;                                                 \
	 fi;                                                            \
	 eval2 $(MAKE) IMGFILE=$(IMGFILE) open;                         \
	 trap="eval2 $(MAKE) IMGFILE=$(IMGFILE) close";                 \
	 trap "$$trap" EXIT;                                            \
	 trap echo SIGINT;                                              \
	 diskprompt;                                                    \
	 trap - SIGINT;                                                 \
	 eval2 mkdir -p mnt.usb;                                        \
	 trap="eval2 rmdir mnt.usb; $$trap";                            \
	 trap "$$trap" EXIT;                                            \
	 eval2 sudo mount /dev/$${DISK}s1a mnt.usb;                     \
	 trap="eval2 sudo umount mnt.usb && $$trap";                    \
	 trap "$$trap" EXIT;                                            \
	 eval2 sh mnt.usb/mount.sh -d;                                  \
	 trap="eval2 mnt.usb/umount.sh && $$trap";                      \
	 trap "$$trap" EXIT;                                            \
	 eval2 sudo chflags noschg mnt.usb/mount.sh mnt.usb/umount.sh;  \
	 trap="eval2 sudo chflags schg mnt.usb/mount.sh; $$trap";       \
	 trap="eval2 sudo chflags schg mnt.usb/umount.sh; $$trap";      \
	 trap "$$trap" EXIT;                                            \
	 if eval2 type rsync > /dev/null 2>&1; then                     \
	 	eval2 sudo rsync -avSH --exclude .uuid --exclude geli   \
	 		mnt/ mnt.usb/;                                  \
	 else                                                           \
	 	dirs=$$( eval2 sudo find mnt/ -mindepth 1 -type d );    \
	 	echo "$$dirs";                                          \
	 	echo "$$dirs" | eval2 sed -e "'s/^mnt/&.usb/'" |        \
	 		eval2 sudo xargs mkdir -pv;                     \
	 	files=$$( eval2 sudo find mnt/ -type f                  \
	 		! -name .uuid ! -path "'*/geli/*'" );           \
	 	echo "$$files";                                         \
	 	echo "$$files" |                                        \
	 		eval2 sed -e "'s/^mnt//;s/.*/mnt& mnt.usb&/'" | \
	 		eval2 sudo xargs -n2 cp -fav;                   \
	 fi

synctoimg: open
	@$(EVAL2); \
	 $(DISKPROMPT); \
	 set -e;                                                            \
	 trap="eval2 $(MAKE) IMGFILE=$(IMGFILE) close";                     \
	 trap "$$trap" EXIT;                                                \
	 trap echo SIGINT;                                                  \
	 diskprompt;                                                        \
	 trap - SIGINT;                                                     \
	 eval2 mkdir -p mnt.usb;                                            \
	 trap="eval2 rmdir mnt.usb; $$trap";                                \
	 trap "$$trap" EXIT;                                                \
	 eval2 sudo mount /dev/$${DISK}s1a mnt.usb;                         \
	 trap="eval2 sudo umount mnt.usb && $$trap";                        \
	 trap "$$trap" EXIT;                                                \
	 eval2 sh mnt.usb/mount.sh -d;                                      \
	 trap="eval2 mnt.usb/umount.sh && $$trap";                          \
	 trap "$$trap" EXIT;                                                \
	 eval2 sudo chflags noschg mnt/mount.sh mnt/umount.sh;              \
	 trap="eval2 sudo chflags schg mnt/mount.sh; $$trap";               \
	 trap="eval2 sudo chflags schg mnt/umount.sh; $$trap";              \
	 trap "$$trap" EXIT;                                                \
	 if eval2 type rsync > /dev/null 2>&1; then                         \
	 	eval2 sudo rsync -avSH --exclude .uuid --exclude geli       \
	 		mnt.usb/ mnt/;                                      \
	 else                                                               \
	 	dirs=$$( eval2 sudo find mnt.usb/ -mindepth 1 -type d );    \
	 	echo "$$dirs";                                              \
	 	echo "$$dirs" | eval2 sed -e "'s/^mnt.usb/mnt/'" |          \
	 		eval2 sudo xargs mkdir -pv;                         \
	 	files=$$( eval2 sudo find mnt.usb/ -type f                  \
	 		! -name .uuid ! -path "'*/geli/*'" );               \
	 	echo "$$files";                                             \
	 	echo "$$files" |                                            \
	 		eval2 sed -e "'s/^mnt.usb//;s/.*/mnt.usb& mnt&/'" | \
	 		eval2 sudo xargs -n2 cp -fav;                       \
	 fi

.PHONY: status

status:
	@$(MOUNTED);                                                        \
	 $(MOUNTDEV);                                                       \
	 if [ -e $(IMGFILE) ]; then                                         \
	 	if md=$$( sudo mdconfig -lf $(IMGFILE) 2> /dev/null ); then \
	 		md="$${md%%[$$IFS]*}";                              \
	 		echo "$(IMGFILE) is attached to $$md";              \
	 	else                                                        \
	 		echo "$(IMGFILE) is not attached";                  \
	 	fi;                                                         \
	 else                                                               \
	 	echo "$(IMGFILE) does not exist";                           \
	 fi;                                                                \
	 if [ -e mnt ]; then                                                \
	 	if mounted -q /dev/$${md}s1a mnt; then                      \
	 		echo "$(IMGFILE) is mounted on mnt";                \
	 		mnt_mounted=1;                                      \
	 	else                                                        \
	 		dotdev=$$( mountdev -q . );                         \
	 		mntdev=$$( mountdev -q mnt );                       \
	 		if [ "$$mntdev" != "$$dotdev" ]; then               \
	 			echo "Foreign device mounted on mnt";       \
	 		else                                                \
	 			echo "$(IMGFILE) is not mounted";           \
	 		fi;                                                 \
	 	fi;                                                         \
	 elif [ -e "$(IMGFILE)" ]; then                                     \
	 	echo "$(IMGFILE) is not mounted";                           \
	 fi;                                                                \
	 for named_eli in $${md:+keys=s1d encstore=s1e}; do                 \
	 	name="$${named_eli%%=*}";                                   \
	 	eli="$$md$${named_eli#*=}.eli";                             \
	 	if geli status $$eli > /dev/null 2>&1; then                 \
	 		echo "$(IMGFILE) $$name ($$eli) is attached";       \
	 	else                                                        \
	 		echo "$(IMGFILE) $$name ($$eli) is not attached";   \
	 	fi;                                                         \
	 	if mounted -q /dev/$$eli mnt/$$name; then                   \
	 		echo "$(IMGFILE) $$name is mounted on mnt/$$name";  \
	 	else                                                        \
	 		echo "$(IMGFILE) $$name is not mounted";            \
	 	fi;                                                         \
	 done;                                                              \
	 mntdev=;                                                           \
	 if [ -e mnt.usb ]; then                                            \
	 	dotdev=$$( mountdev -q . );                                 \
	 	mntdev=$$( mountdev -q mnt.usb );                           \
	 	if [ "$$mntdev" != "$$dotdev" ]; then                       \
	 		echo "$$mntdev device is mounted on mnt.usb";       \
	 	else                                                        \
	 		echo "No device is mounted on mnt.usb";             \
	 		mntdev=;                                            \
	 	fi;                                                         \
	 fi;                                                                \
	 for named_eli in $${mntdev:+keystore=s1d encstore=s1e}; do         \
	 	name="$${named_eli%%=*}";                                   \
	 	eli="$$md$${named_eli#*=}.eli";                             \
	 	if geli status $$eli > /dev/null 2>&1; then                 \
	 		echo "$$name ($$eli) is attached";                  \
	 	else                                                        \
	 		echo "$$name ($$eli) is not attached";              \
	 	fi;                                                         \
	 done

.PHONY: clean distclean

clean: close
	@$(EVAL2);                                \
	 set -e;                                  \
	 [ ! -e mnt ] || eval2 rmdir mnt;         \
	 [ ! -e mnt.usb ] || eval2 rmdir mnt.usb

distclean: clean
	@$(EVAL2);                                          \
	 $(YESNO);                                          \
	 set -e;                                            \
	 [ -e $(IMGFILE) ] || exit 0;                       \
	 yesno -n "Delete $(IMGFILE) and host keys? [N]: "; \
	 eval2 rm -f $(IMGFILE);                            \
	 eval2 rm -f geli/ffhost-*.key;                     \
	 eval2 rmdir geli \|\| :

################################################################################
# END
################################################################################
