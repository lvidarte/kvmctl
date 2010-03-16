#!/bin/bash
# ============================================================================
# KVMCTL - Simple way to manage your KVM virtual machines
#
# @see    http://github.com/lvidarte/kvmctl.git
# @author Leonardo Vidarte <lvidarte[AT]gmail.com>
# ============================================================================

BASEDIR="/var/local/kvm"
KVM="/usr/bin/kvm"
KVM_CONFIG="settings.cfg"

do_help()
{
	PROGRAM_NAME=`basename $0`
	echo "Usage:"
	echo "$PROGRAM_NAME machine (start|startd|stop|monitor|status|settings|edit)"
	echo "$PROGRAM_NAME (--help|--list|--show)"
}

if [ $# -eq 0 ]; then
	do_help
	exit 1
fi

if [ "$1" == "--help" ]; then
	do_help
	exit 0
fi

if [ "$1" == "--list" ]; then
	ls -1 $BASEDIR
	exit 0
fi

if [ "$1" == "--show" ]; then
	ps -ef | awk -v format="%-19s %-7s %-7s %s\n" '\
		BEGIN { \
			printf(format,"MACHINE", "PID", "STIME", "TIME") \
		} \
		/kvm -name/&&!/awk/ { \
			printf(format, $10, $2, $5, $7) \
		}'
	exit 0
fi

MACHINE=$1
MACHINEDIR=$BASEDIR/$MACHINE

if [ ! -d $MACHINEDIR ]; then
	echo -e "Error. (Machine not found at $BASEDIR/)\n"
	do_help
	exit 1
fi

do_load_settings()
{
	if [ -f "$MACHINEDIR/$KVM_CONFIG" ]; then
		source $MACHINEDIR/$KVM_CONFIG
	else
		echo -e "Error. ($MACHINEDIR/$KVM_CONFIG not found)\n"

		echo "Example $KVM_CONFIG:"
		echo 'KVM_M=512M'
		echo 'KVM_HDA=$BASEDIR/$MACHINE/root.qcow2'
		echo 'KVM_HDB=$BASEDIR/.imgs/swap.qcow2'
		echo 'KVM_HDC=$BASEDIR/.imgs/home.qcow2'
		echo 'KVM_HDD='
		echo 'KVM_NET="nic,macaddr=52:54:00:00:02:53 -net tap"'
		echo 'KVM_TCP_PORT=10001'
		echo 'KVM_PIDFILE=/var/run/192.168.0.253.pid'
		echo 'KVM_MONITOR="tcp:127.0.0.1:${KVM_TCP_PORT},server,nowait"'
		echo 'KVM_EXTRA='

		exit 1
	fi
}

do_check_tcp_port()
{
	if [ -z "$1" ]; then
		echo "Error. (KVM_TCP_PORT is not set)"
		exit 1
	fi
}

case "$2" in 

	start|startd)

		do_load_settings

		PARAMS="-name $MACHINE"

		[ "$2" == "startd" ] \
			&& PARAMS="$PARAMS -vnc none -daemonize" \
			&& MSG="(daemon mode)"

		[ -n "$KVM_M" ] && PARAMS="$PARAMS -m $KVM_M"
		[ -n "$KVM_HDA" ] && PARAMS="$PARAMS -hda $KVM_HDA"
		[ -n "$KVM_HDB" ] && PARAMS="$PARAMS -hdb $KVM_HDB"
		[ -n "$KVM_HDC" ] && PARAMS="$PARAMS -hdc $KVM_HDC"
		[ -n "$KVM_HDD" ] && PARAMS="$PARAMS -hdd $KVM_HDD"
		[ -n "$KVM_NET" ] && PARAMS="$PARAMS -net $KVM_NET"
		[ -n "$KVM_PIDFILE" ] && PARAMS="$PARAMS -pidfile $KVM_PIDFILE"
		[ -n "$KVM_MONITOR" ] && PARAMS="$PARAMS -monitor $KVM_MONITOR"

		[ -n "$KVM_EXTRA" ] && PARAMS="$PARAMS $KVM_EXTRA"

		echo "Starting up '$MACHINE' ... $MSG"
		$KVM $PARAMS

		[ $? -ne 0 ] \
			&& echo "Error. (Couldn't run KVM)"
		;;

	stop)

		do_load_settings
		do_check_tcp_port $KVM_TCP_PORT

		echo "Shutting down '$MACHINE' ..."
		echo "system_powerdown" | nc 127.0.0.1 $KVM_TCP_PORT &>/dev/null

		if [ $? -ne 0 ]; then
			echo "Error. (Couldn't connect. Is the machine up?)"
			exit 1
		fi

		;;

	monitor)

		do_load_settings
		do_check_tcp_port $KVM_TCP_PORT
		
		echo "Starting Monitor for '$MACHINE'... (Ctrl+C to exit)"
		nc 127.0.0.1 $KVM_TCP_PORT

		;;

	status)

		do_load_settings
		do_check_tcp_port $KVM_TCP_PORT

		INFO="info status\ninfo kvm\ninfo network"

		echo -e $INFO | nc -w 1 127.0.0.1 $KVM_TCP_PORT \
			&& echo ""

		if [ $? -ne 0 ]; then
			echo "Error. (Couldn't connect. Is the machine up?)"
			exit 1
		fi

		;;
	
	settings)

		do_load_settings
		cat $MACHINEDIR/$KVM_CONFIG

		;;
	
	edit)

		if [ -z "$EDITOR" ]; then
			echo "Error. (EDITOR is not set)"
			exit 1
		fi

		do_load_settings

		if [ -n "$KVM_PIDFILE" -a -f "$KVM_PIDFILE" ]; then
			echo -n "Warning! '$MACHINE' is running. Continue? (y/N) "
			read CONTINUE

			[ "$CONTINUE" != "y" -a "$CONTINUE" != "Y" ] \
				&& exit 1

		fi

		$EDITOR $MACHINEDIR/$KVM_CONFIG

		;;

	*)
		do_help
		exit 1
		;;

esac

exit 0
