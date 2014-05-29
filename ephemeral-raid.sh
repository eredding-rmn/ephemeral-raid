#!/bin/sh
#
### BEGIN INIT INFO
# Provides:          ephemeral-raid
# Required-Start:    $local_fs $network $named $remote_fs 
# Should-Start:      $time
# Required-Stop:
# Should-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: makes raid of ephemeral disks during startup
# Description:       makes raid of ephemeral disks during startup
### END INIT INFO

# Return values acc. to LSB for all commands but status:
# 0       - success
# 1       - generic or unspecified error
# 2       - invalid or excess argument(s)
# 3       - unimplemented feature (e.g. "reload")
# 4       - user had insufficient privileges
# 5       - program is not installed
# 6       - program is not configured
# 7       - program is not running
# 8--199  - reserved (8--99 LSB, 100--149 distrib, 150--199 appl)
# 
# Note that starting an already running service, stopping
# or restarting a not-running service as well as the restart
# with force-reload (in case signaling is not supported) are
# considered a success.
PATH=/sbin:/usr/sbin:/bin:/usr/bin

RETVAL=0

prog=$(basename $0)
logger="logger -t $prog"
system=unknown

if [ -f /etc/redhat-release ]; then
    system=redhat
elif [ -f /etc/system-release ]; then
    system=redhat
elif [ -f /etc/debian_version ]; then
    system=debian
fi

# If there exist sysconfig/default variable override files use it...

if [ "$system" = "redhat" ]; then
    ## source platform specific external scripts
    . /etc/init.d/functions
    [ -r /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog

    ## set or override platform specific variables
    lockfile=${LOCKFILE-/var/lock/subsys/$prog}
    log_daemon_msg() {
        echo -n $"$1"
    }
    echo_ok() {
        echo_success; echo
    }
    echo_fail() {
        echo_failure; echo
    }
    log_success_msg() {
        success $"$@"
    }
    log_failure_msg() {
        failure $"$@"
        echo $"$@"
    }
    log_action_msg () {
        echo "$@."
    }

    log_action_begin_msg () {
        echo -n "$@..."
    }

    log_action_cont_msg () {
        echo -n "$@..."
    }
fi


if [ "$system" = "debian" ]; then
    ## source platform specific external scripts
    . /lib/lsb/init-functions
    [ -r /etc/default/$prog ] && . /etc/default/$prog

    ## set or override platform specific variables
    lockfile=${LOCKFILE-/var/lock/$prog}
    echo_ok() {
        log_end_msg 0
    }
    echo_fail() {
        log_end_msg 1
    }
fi


EPHEMERAL_DISKS=${EPHEMERAL_DISKS:-''}
EPHEMERAL_DISK_COUNT=${EPHEMERAL_DISK_COUNT:-0}
MDADM=${MDADM:-'/sbin/mdadm'}
EPHEMERAL_RAID_DEVICE=${EPHEMERAL_RAID_DEVICE:-'/dev/md99'}
EPHEMERAL_RAID_DEVICE_NAME=${EPHEMERAL_RAID_DEVICE_NAME:-"ephemeral-raid0"}
EPHEMERAL_RAID_DEVICE_OPTS=${EPHEMERAL_RAID_DEVICE_OPTS:-"--chunk=1024"}
EPHEMERAL_RAID_LEVEL=${EPHEMERAL_RAID_LEVEL:-0}
EPHEMERAL_RAID_FS_FORMAT=${EPHEMERAL_RAID_FS_FORMAT:-"mkfs.ext4"}
EPHEMERAL_RAID_SWAP=${EPHEMERAL_RAID_SWAP:-false}
EPHEMERAL_RAID_SWAP_SIZE=${EPHEMERAL_RAID_SWAP_SIZE:-0}
EPHEMERAL_RAID_SWAP_PARTITION=${EPHEMERAL_RAID_SWAP_PARTITION:-}
EPHEMERAL_RAID_FS_PARTITION=${EPHEMERAL_RAID_FS_PARTITION:-${EPHEMERAL_RAID_DEVICE}}
EPHEMERAL_RAID_FS_MOUNT_POINT=${EPHEMERAL_RAID_FS_MOUNT_POINT:-"/srv/temp"}
EPHEMERAL_RAID_FS_MOUNT_POINT_OWNER=${EPHEMERAL_RAID_FS_MOUNT_POINT_OWNER:-"root"}
EPHEMERAL_RAID_FS_MOUNT_POINT_GROUP=${EPHEMERAL_RAID_FS_MOUNT_POINT_GROUP:-"root"}
EPHEMERAL_RAID_FS_MOUNT_POINT_MODE=${EPHEMERAL_RAID_FS_MOUNT_POINT_MODE:-755}
PARTED='/sbin/parted'

ensure_dir () {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

set_mountpoint_permissions() {
    chown $EPHEMERAL_RAID_FS_MOUNT_POINT_OWNER:${EPHEMERAL_RAID_FS_MOUNT_POINT_GROUP} $EPHEMERAL_RAID_FS_MOUNT_POINT
    chmod $EPHEMERAL_RAID_FS_MOUNT_POINT_MODE $EPHEMERAL_RAID_FS_MOUNT_POINT
}

is_true () {
    if [ "x$1" = "xtrue" -o "x$1" = "xyes" -o "x$1" = "x0" ] ; then
       return 0
    else
        return 1
    fi
}

autodiscover_ephemeral_by_metadata () {
        log_action_begin_msg "Autodiscover"
        EPHEMERAL_DISK_COUNT=0
        EPHEMERAL_DISKS=''
        CMD='curl -qs http://169.254.169.254/latest/meta-data/block-device-mapping/'
        local ephemeral_disks=$(${CMD} | grep ephemeral)
        if [ -z "${ephemeral_disks}" ]; then
            log_action_msg "No Ephemeral disks found!!"
            echo_ok
            exit 0
        fi
        for disk in ${ephemeral_disks}; do 
            local diskname=$( ${CMD}/${disk})
            adisk=/dev/${diskname/sd/xvd}
            EPHEMERAL_DISKS="${EPHEMERAL_DISKS} ${adisk}"
            log_action_cont_msg "found: ${adisk} "
            EPHEMERAL_DISK_COUNT=$(( ${EPHEMERAL_DISK_COUNT}+1 ))
        done
        echo
        log_action_msg "Discovered ($EPHEMERAL_DISK_COUNT): $EPHEMERAL_DISKS"
}

mk_raid () {
    if [ ! -e ${MDADM} ]; then
        $log_daemon_msg "FAILED TO START; missing ${MDADM}"
        echo_fail
        exit 5
    fi;
    $MDADM --create ${EPHEMERAL_RAID_DEVICE} --run --level ${EPHEMERAL_RAID_LEVEL} --chunk=1024 --name="${EPHEMERAL_RAID_DEVICE_NAME}" --raid-devices=${EPHEMERAL_DISK_COUNT} ${EPHEMERAL_DISKS}
    retval=$?
    bail_check $retval "Ephemeral disk raid configuration FAILED"
    return $retval
}

stop_raid () {
    if [ ! -e ${MDADM} ]; then
        log_action_msg "what are you doing trying to stop??? ERROR: missing ${MDADM}"
        echo_fail
        exit 5
    fi;
    $MDADM --stop ${EPHEMERAL_RAID_DEVICE}
}

mk_swap () {
    MKSWAP=$(which mkswap)
    log_action_cont_msg " mkswap... "
    ${MKSWAP} ${EPHEMERAL_RAID_SWAP_PARTITION}
    activate_swap
}


mk_fs () {
    log_action_msg "start format of ${EPHEMERAL_RAID_FS_PARTITION}..."
    if [ ! -b ${EPHEMERAL_RAID_FS_PARTITION} ]; then
        log_action_msg "FAILURE: block device $EPHEMERAL_RAID_FS_PARTITION is not a block device!"
        return 1
    fi
    ${EPHEMERAL_RAID_FS_FORMAT}  ${EPHEMERAL_RAID_FS_PARTITION} > /dev/null 2>&1 
    bail_check $?  "FAILURE: format of ${EPHEMERAL_RAID_FS_PARTITION} was not successful"
    log_action_msg "...format of ${EPHEMERAL_RAID_FS_PARTITION} complete" 
    return 0 
}

mk_partitions () {
    # backup partition table:
    log_action_cont_msg "partitioning"
    check_parted
    ${PARTED} ${EPHEMERAL_RAID_DEVICE} --align optimal --script -- mkpart primary 0% ${EPHEMERAL_RAID_SWAP_SIZE}MB
    ${PARTED} ${EPHEMERAL_RAID_DEVICE} --align optimal --script -- mkpart primary ${EPHEMERAL_RAID_SWAP_SIZE}MB 100%
    #${PARTED} ${DEVICE} --script print
    return $?
}


mk_label() {
    DEVICE=$1
    check_parted
    ${PARTED} ${DEVICE} --script -- mklabel gpt
    return $?
}

check_parted(){
    if [[ -z "${PARTED}" ]]; then
        log_action_msg "FAILED TO START: partitioning was configured, however, the executable 'parted' was not found; cannot partition"
        exit 5
    fi
}

is_mounted() {
    if grep ${EPHEMERAL_RAID_FS_MOUNT_POINT%/} /proc/mounts  &> /dev/null; then
        return 0
    else
        return 1
    fi
}

mount_partition() {
    MNT=$(which mount)
    if [ -d $EPHEMERAL_RAID_FS_MOUNT_POINT ]; then
        log_action_msg "$EPHEMERAL_RAID_FS_MOUNT_POINT exists... "
    fi
    if is_true is_mounted; then
        log_action_msg "$EPHEMERAL_RAID_FS_MOUNT_POINT already mounted; failing"
        echo_fail
        exit 1
    fi

    ensure_dir $EPHEMERAL_RAID_FS_MOUNT_POINT
    ${MNT}  ${EPHEMERAL_RAID_FS_PARTITION} ${EPHEMERAL_RAID_FS_MOUNT_POINT}
    set_mountpoint_permissions $EPHEMERAL_RAID_FS_MOUNT_POINT $EPHEMERAL_RAID_FS_MOUNT_POINT_OWNER
    return $?
}

unmount_partition() {
    UMNT=$(which umount)
    ${UMNT}  ${EPHEMERAL_RAID_FS_MOUNT_POINT%/}
    return $retval
}

activate_swap() {
    /sbin/swapon ${EPHEMERAL_RAID_SWAP_PARTITION} 
    bail_check $?  "FAILURE: Swap ${EPHEMERAL_RAID_SWAP_PARTITION} failed to activate";
    log_action_msg "Swap ${EPHEMERAL_RAID_SWAP_PARTITION} activated" 
    return $retval
}

deactivate_swap () {
    if /sbin/swapoff ${EPHEMERAL_RAID_SWAP_PARTITION}; then
        log_action_msg "Swap ${EPHEMERAL_RAID_SWAP_PARTITION} deactivated" 
    else 
        log_action_msg "FAILURE: Swap ${EPHEMERAL_RAID_SWAP_PARTITION} failed to deactivate";
    fi
}

# pass retval to this to check if we need to stop raid and bail
bail_check() {
    val=${1}
    msg=${2:-""}
    if [[ ! $val -eq 0 ]]; then
        if [[ "x$msg" != "x" ]]; then 
            log_action_msg "$msg"; 
        fi 
        unmount_partition
        if is_true "$EPHEMERAL_RAID_SWAP"  && [ ! -z "${EPHEMERAL_RAID_SWAP_PARTITION}" ]; then
            deactivate_swap
        fi
        stop_raid
        echo_fail
        exit 1
    fi
}

start() {
    status &> /dev/null
    bail_check $?  "${EPHEMERAL_RAID_DEVICE} already exists; exiting..."

    if [ -z $EPHEMERAL_DISKS ]; then
        autodiscover_ephemeral_by_metadata
    fi

    log_daemon_msg "Starting $prog: " "${prog}"
    mk_raid
    mk_label ${EPHEMERAL_RAID_DEVICE}
    if is_true "$EPHEMERAL_RAID_SWAP"  && [ ! -z "${EPHEMERAL_RAID_SWAP_PARTITION}" ]; then
        mk_partitions
        mk_swap
        bail_check $?
    else
        log_action_msg "Ephemeral swap skipped"
    fi
    mk_fs
    bail_check $? "creating filesystem failed"
    mount_partition
    bail_check $? "mounting partition failed"
    echo_ok
    return $RETVAL
}

stop() {
    log_daemon_msg "Shutting down $prog: " "${prog}"
    unmount_partition
    bail_check $? "Failed to unmount $EPHEMERAL_RAID_FS_MOUNT_POINT"
    if is_true "$EPHEMERAL_RAID_SWAP"  && [ ! -z "${EPHEMERAL_RAID_SWAP_PARTITION}" ]; then
        deactivate_swap
    fi 
    stop_raid
    bail_check $? "Failed to stop RAID"
    echo_ok
    # No-op
    RETVAL=7
    return $RETVAL
}

status() {
    if [ -e $EPHEMERAL_RAID_DEVICE ]; then
        log_action_msg "${prog} $EPHEMERAL_RAID_DEVICE exists.. "
        if is_true is_mounted; then
            log_action_msg "$EPHEMERAL_RAID_FS_MOUNT_POINT mounted.. "
        fi
        return 1
    else
        log_action_msg "${prog} $EPHEMERAL_RAID_DEVICE does not exist; not started"
        return 0
    fi 
}

moarstatus() {
    if [ -b $EPHEMERAL_RAID_DEVICE ]; then 
        ${PARTED} $EPHEMERAL_RAID_DEVICE --script -- print 
    else
        log_action_msg "${EPHEMERAL_RAID_DEVICE} isn't created"
    fi
    grep  ${EPHEMERAL_RAID_FS_MOUNT_POINT%/} /proc/mounts  
    cat /proc/mdstat
    swapon -s
    df -h
}

case "$1" in
    start)
        start
        RETVAL=$?
        ;;
    stop)
        stop
        RETVAL=$?
        ;;
    restart|try-restart|condrestart|reload|force-reload)
        ## Stop the service and regardless of whether it was
        ## running or not, start it again.
        # 
        ## Note: try-restart is now part of LSB (as of 1.9).
        ## RH has a similar command named condrestart.
        # THIS IS A DESTRUCTIVE PROCESS
        log_action_msg "No action being taken. This is a destructive process.  I just saved your life.  You're welcome."
        echo_ok
        RETVAL=3
        ;;
    moar-status)
        ### this is a diagnostic, non-lsb compliant level; outputs various bits of data we check 
        ###  that are configured with the init script
        moarstatus
        echo_ok
        RETVAL=0
        ;;
    status)
        log_action_msg "Checking for block device for service $prog:"
        # Return value is slightly different for the status command:
        # 0 - service up and running
        # 1 - service dead, but /var/run/  pid  file exists
        # 2 - service dead, but /var/lock/ lock file exists
        # 3 - service not running (unused)
        # 4 - service status unknown :-(
        # 5--199 reserved (5--99 LSB, 100--149 distro, 150--199 appl.)
        if status; then
            echo_ok
            exit 3
        fi
        echo_ok
        RETVAL=1
        ;;
    *)
        echo "Usage: $0 {start|stop|status|try-restart|condrestart|restart|force-reload|reload}"
        RETVAL=3
        ;;
esac

exit $RETVAL

