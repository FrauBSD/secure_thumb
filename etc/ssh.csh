# -*- tab-width:  4 -*- ;; Emacs
# vi: set tabstop=8     :: Vi/ViM
############################################################ IDENT(1)
#
# $Title: csh(1) semi-subroutine file $
# $Copyright: 2015-2018 Devin Teske. All rights reserved. $
# $FrauBSD: secure_thumb/etc/ssh.csh 2019-09-10 17:00:41 +0430 kfvahedi $
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
setenv interactive 0
if ( $?prompt ) then
        setenv interactive 1
endif

#
# OS Specifics
#
setenv UNAME_s `uname -s`

#
# For dialog(1) and Xdialog(1) menus -- mainly cvspicker in FUNCTIONS below
#
setenv DIALOG_MENU_TAGS 123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ

#
# Default directory to store dialog(1) and Xdialog(1) temporary files
#
setenv DIALOG_TMPDIR /tmp

############################################################ ALIASES

unalias quietly >& /dev/null
alias quietly '\!* >& /dev/null'

quietly unalias have
alias have 'which \!* >& /dev/null'

quietly unalias eval2
alias eval2 'echo \!*; eval \!*'

#
# cannot do file-descriptor manipulation in [t]csh
#
alias csh_na 'echo "Not available for [t]csh"; false'
alias path_munge csh_na
alias fprintf    csh_na
alias eprintf    csh_na

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
alias dialog_menutag "/bin/sh -c '"'                                        \\
        tmpfile="$DIALOG_TMPDIR/dialog.menu.$$"                             \\
                                                                            \\
        [ -f "$tmpfile" ] || return ${FAILURE:-1}                           \\
                                                                            \\
        cat "$tmpfile" 2> /dev/null                                         \\
        quietly rm -f "$tmpfile"                                            \\
                                                                            \\
        return ${SUCCESS:-0}                                                \\
'"' -- /bin/sh"

# dialog_menutag2help $tag_chosen $tag1 $item1 $help1 \
#                                   $tag2 $item2 $help2
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
alias dialog_menutag2help "/bin/sh -c '"'                                   \\
        tag="$1" tagn help                                                  \\
        shift 1 # tag                                                       \\
                                                                            \\
        while [ $# -gt 0 ]; do                                              \\
                tagn="$1"                                                   \\
                help="$3"                                                   \\
                shift 3 # tagn/item/help                                    \\
                                                                            \\
                if [ "$tag" = "$tagn" ]; then                               \\
                        echo "$help"                                        \\
                        return ${SUCCESS:-0}                                \\
                fi                                                          \\
        done                                                                \\
        return ${FAILURE:-1}                                                \\
'"' -- /bin/sh"

# colorize [-c ANSI] [-e ANSI] pattern
#
# Colorize text matching pattern with ANSI sequence (default is `31;1' for red-
# bold). Non-matching lines are printed as-is.
#
# NB: Requires awk(1) -- from base system
#
quietly unalias colorize
alias colorize "/bin/sh -c '"'                                              \\
        OPTIND=1 OPTARG flag                                                \\
        ti=                                                                 \\
        te=                                                                 \\
                                                                            \\
        while getopts c:e: flag; do                                         \\
                case "$flag" in                                             \\
                c) ti="$OPTARG" ;;                                          \\
                e) te="$OPTARG" ;;                                          \\
                esac                                                        \\
        done                                                                \\
        shift $(( $OPTIND - 1 ))                                            \\
                                                                            \\
        awk -v ti="${ti:-31;1}" -v te="${te:-39;22}" -v pattern="$1" "      \\
                gsub(pattern, \"\033[\" ti \"m&\033[\" te \"m\")||1         \\
        " # END-QUOTE                                                       \\
'"' -- /bin/sh"

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
#   ssh-agent
#   : do some ssh-add
#   : do some commits
#   ssh-agent -k
#   : or instead of ``ssh-agent -k'' just wait 30m for it to die
#
quietly unalias ssh-agent
alias ssh-agent 'eval `ssh-agent -c -t 1800 \!*`'

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
