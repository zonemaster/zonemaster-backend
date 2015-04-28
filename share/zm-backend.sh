#!/bin/bash

LOGDIR=/var/log/zonemaster
PIDDIR=/var/run
LISTENIP=127.0.0.1
USER=www-data
GROUP=www-data

start() {
    if [ ! -d $LOGDIR ]
    then
        mkdir -p $LOGDIR
    fi
    
    if [ ! -d $PIDDIR]
    then
        mkdir -p $PIDDIR
    fi
    
    starman --user=$USER --group=$GROUP --error-log=$LOGDIR/zm-starman-error.log --pid=$PIDDIR/zm-starman.pid --listen=$LISTENIP:5000 --daemonize /usr/local/bin/zonemaster_webbackend.psgi
    zm_web_daemon --user=$USER --group=$GROUP --pidfile=$PIDDIR/zm_web_daemon.pid start
}

stop() {
    zm_web_daemon --user=$USER --group=$GROUP --pidfile=$PIDDIR/zm_web_daemon.pid stop
    kill `cat $PIDDIR/zm-starman.pid`
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "usage: $0 [start|stop|restart]"
        exit 1
esac
exit 0
