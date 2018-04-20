#!/usr/bin/env bash

[ ! -e "$JAVA_HOME/bin/java" ] && JAVA_HOME=/usr/local/java/jdk1.8.0_111
[ ! -e "$JAVA_HOME/bin/java" ] && echo "Please set the JAVA_HOME variable in your environment, We need java(x64)!" && exit 1

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/jre/lib

BASE_DIR=$(dirname $(dirname $0))
LOG_DIR=$BASE_DIR/logs
LOG_FILE=$LOG_DIR/boot.log

BOOT_JAR=$BASE_DIR/config-cloud.jar

BOOT_PID=$BASE_DIR/bin/boot.pid

#===========================================================================================
# Parsing command arguments
#===========================================================================================
ORIGIN_ARGS="$*"
TEMP=`getopt --long server.port:,log.node.index:,boot.pid:,boot.log.file: -n 'Arguments not correct' -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- $TEMP
while true ; do
    case "$1" in
    --server.port)
        SERVER_PORT=$2
        shift 2
    ;;
    --log.node.index)
        LOG_NODE_INDEX=$2
        shift 2
    ;;
    --boot.pid)
        BOOT_PID=$2
        shift 2
    ;;
    --boot.log.file)
        LOG_FILE=$2
        shift 2
    ;;
    --)
        shift ; break
    ;;
    *)
        echo "Internal error!" ; exit 1
    ;;
    esac
done
eval set $ORIGIN_ARGS

LOG_DIR=$(dirname $LOG_FILE)
if [ ! -d "$LOG_DIR" ]; then
    mkdir "$LOG_DIR"
fi

PID_DIR=$(dirname $BOOT_PID)
if [ ! -d "$PID_DIR" ]; then
    mkdir "$PID_DIR"
fi

#===========================================================================================
# JVM Configuration
#===========================================================================================
#JAVA_OPTS="$JAVA_OPTS -Dspring.profiles.active=dev"
#JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Djava.security.egd=file:/dev/./urandom"

JAVA_OPTS="$JAVA_OPTS -server -Xms1g -Xmx1g -Xss256k"
JAVA_OPTS="$JAVA_OPTS -XX:NewRatio=2 -XX:SurvivorRatio=8"
JAVA_OPTS="$JAVA_OPTS -XX:PermSize=256m -XX:MaxPermSize=256m -XX:MaxDirectMemorySize=512m -XX:LargePageSizeInBytes=4m -XX:MaxTenuringThreshold=6 -XX:PretenureSizeThreshold=0 "

JAVA_OPTS="$JAVA_OPTS -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly -XX:+DisableExplicitGC"
JAVA_OPTS="$JAVA_OPTS -XX:-OmitStackTraceInFastThrow"
JAVA_OPTS="$JAVA_OPTS -Djava.ext.dirs=$BASE_DIR/lib:$JAVA_HOME/jre/lib/ext:."
#JAVA_OPTS="$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=$DEBUG_PORT,server=y,suspend=n"
JAVA_OPTS="$JAVA_OPTS -cp $CLASSPATH"

#===========================================================================================
# functions
#===========================================================================================
start() {
    if [ -f "$BOOT_PID" ]; then
        if [ -s "$BOOT_PID" ]; then
            echo "Existing PID file found during start."
            exit 1
        fi
    fi
    program_args=''
    if [ -z "$SERVER_PORT" ]; then
        echo "NOTE:Using server port in spring configuration."
    else
        program_args="--server.port=$SERVER_PORT"
    fi

    if [ ! -z "$LOG_NODE_INDEX" ]; then
        program_args="$program_args --sirun.logging.nodeIndex=$LOG_NODE_INDEX"
    fi

    > $LOG_FILE

    java $JAVA_OPTS -jar $BOOT_JAR $program_args >> $LOG_FILE 2>&1 &

    echo $! > "$BOOT_PID"
    echo "========= started ==============="
}

stop(){
    if [ -f "$BOOT_PID" ]; then
        if [ -s "$BOOT_PID" ]; then
            kill `cat "$BOOT_PID"` > /dev/null 2>&1
            if [ $? -gt 0 ]; then
                echo "PID file found but no matching process was found. Stop aborted."
                rm -rf $BOOT_PID >/dev/null 2>&1
            else
                rm -f "$BOOT_PID" >/dev/null 2>&1
            fi
        else
            echo "PID file is empty and has been ignored."
        fi
    else
        echo "\\$BOOT_PID was set but the specified file does not exist. Is BOOT running? Stop aborted."
    fi
}

status() {
    if [ -f "$BOOT_PID" ] && ps -ef | grep `cat \$BOOT_PID` | grep 'spring.profiles.active'; then
        echo "BOOT is running"
        ps -ef | grep `cat \$BOOT_PID` | grep 'spring.profiles.active'
    else
        echo "BOOT is not running"
    fi
}

clean() {
    rm -rf $LOG_DIR/*
}

#===========================================================================================
# commands
#===========================================================================================
case "$1" in
    'start')
    start
    ;;
    'stop')
    stop
    ;;
    'restart')
    stop
    start
    ;;
    'status')
    status
    ;;
    'clean')
    clean
    ;;
    *)
    echo "Usage: \$0 {start|stop|restart|status|clean"
    exit 1
esac
exit 0


