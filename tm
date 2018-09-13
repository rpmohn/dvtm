#!/bin/sh

# Copyright 2012-2016 Ross Palmer Mohn <rpmohn@waxandwane.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

SCRIPTPATH=$0
SCRIPT=`basename $SCRIPTPATH`
NAME="$SCRIPT@`hostname -s`"

RCDIR="$HOME/.$SCRIPT"
if [ $# -gt 1 -a "$1" = "-d" ]; then
	RCDIR="$2"
	shift 2
fi

BASE="$RCDIR/$NAME"
RCFILE="$RCDIR/${SCRIPT}rc"

errout() {
	echo "$1" 1>&2
	exit 1
}

#### Beginning of Configuration File ####
[ -d $RCDIR ] || mkdir -p $RCDIR || errout "Error creating directory $RCDIR"
[ -f "$RCFILE" ] || cat >"$RCFILE" <<EOF
# Status bar settings
STATUS_COMMAND="date +%H:%M"
STATUS_INTERVAL=60

# dvtm path and options
DVTM="dvtm"
DVTM_OPTS=""
DVTM_DBG="/dev/null"

# detach path and options
DETACH="abduco"
DETACH_OPTS=""

# vim: syntax=sh
EOF
[ -f "$RCFILE" ] || errout "Error creating file $RCFILE"
. $RCFILE
#### End of Configuration File ##########

# Pre-launch will either connect to an existing session or launch a new session
prelaunch() {
	if [ "x$TM_DVTM_UID" != "x" ]; then
		errout "You're already inside $NAME"
	fi

	# Set terminal window title to include the session name
	printf "\033]0;$NAME\007"

	# $DETACH will either reconnect or launch a new session
	$DETACH $DETACH_OPTS -A "$BASE.session" $SCRIPTPATH -d $RCDIR --launch
	exit 0
}

# When creating a new session, the script is rerun by $DETACH with the --launch parameter
launch() {
	export TM_DVTM_UID=$NAME

	# Setup the status FIFO
	FIFO="$BASE.status"
	[ -p "$FIFO" ] || mkfifo "$FIFO"
	chmod 600 $FIFO

	while true; do
		echo `eval $STATUS_COMMAND | tr -d '\n'`
		sleep $STATUS_INTERVAL
	done > $FIFO &
	STATUS_PID=$!

	# Launch a new session
	$DVTM $DVTM_OPTS -t "$NAME" -s $FIFO 2> $DVTM_DBG
	kill $STATUS_PID
	rm "$FIFO"

	exit 0
}

[ $# -eq 0 ] && prelaunch

if [ $# -eq 1 ]; then
	case "$1" in
		--launch)		launch; break ;;
		-v|--version)	echo "Terminal Management, tm-0.4 © 2012-2016, Ross Palmer Mohn"; exit 0 ;;
	esac
fi

echo "usage: $SCRIPT [-v] [-d rcdir]"
