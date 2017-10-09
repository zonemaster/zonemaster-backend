#!/bin/bash
#
### BEGIN INIT INFO
# Provides:          zm-backend
# Required-Start:    mysql $network $local_fs
# Required-Stop:     mysql $network $local_fs
# Should-Start:
# Should-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop the Zonemaster Backend (RPC API daemon and Test Agent daemon)
# Description:       Control script for the two demon processes that
#                    make up the Zonemaster Backend.
### END INIT INFO

LOGDIR=/var/log/zonemaster
PIDDIR=/var/run/zonemaster
LISTENIP=127.0.0.1
USER=www-data
GROUP=www-data

setup() {
    if [ ! -d $LOGDIR ]
    then
        mkdir -p $LOGDIR
    fi

    if [ ! -d $PIDDIR ]
    then
        mkdir -p $PIDDIR
    fi

    chown -R www-data $LOGDIR
    chown -R www-data $PIDDIR
}

start() {
    setup

    starman --user=$USER --group=$GROUP --error-log=$LOGDIR/zm-starman-error.log --pid=$PIDDIR/zm-starman.pid --listen=$LISTENIP:5000 --daemonize /usr/local/bin/zonemaster_backend_rpcapi.psgi
    /usr/local/bin/zonemaster_backend_testagent --user=$USER --group=$GROUP --pidfile=$PIDDIR/zonemaster_backend_testagent.pid start
}

stop() {
    if [ -f $PIDDIR/zonemaster_backend_testagent.pid ]
    then
        /usr/local/bin/zonemaster_backend_testagent --user=$USER --group=$GROUP --pidfile=$PIDDIR/zonemaster_backend_testagent.pid stop
    fi

    if [ -f $PIDDIR/zm-starman.pid ]
    then
        kill `cat $PIDDIR/zm-starman.pid`
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart|force-reload)
        stop
        start
        ;;
    status)
        ;;
    *)
        echo "usage: $0 [start|stop|restart]"
        exit 1
esac
exit 0
