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

# If there exist sysconfig/default variable override files use it...

if [ "$system" = "redhat" ]; then
    ## source platform specific external scripts
    . /etc/init.d/functions
    [ -r /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog

    ## set or override platform specific variables
    lockfile=${LOCKFILE-/var/lock/subsys/$prog}
    log_daemon_msg() {
        ${logger} -n $"$1"
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
    log_action_msg() {
        echo $@
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
EPHEMERAL_RAID_DEVICE=${EPHEMERAL_RAID_DEVICE:-'/dev/md001'}

EPHEMERAL_RAID_DEVICE_NAME=${EPHEMERAL_RAID_DEVICE_NAME:-'null'}
EPHEMERAL_RAID_DEVICE_OPTS=${EPHEMERAL_RAID_DEVICE_OPTS:-"--chunk=1024"}
EPHEMERAL_RAID_LEVEL=${EPHEMERAL_RAID_LEVEL:-0}
EPHEMERAL_RAID_FS_FORMAT=${EPHEMERAL_RAID_FS_FORMAT})

EPHEMERAL_RAID_SWAP=${EPHEMERAL_RAID_SWAP:-false}
EPHEMERAL_RAID_SWAP_SIZE=${EPHEMERAL_RAID_SWAP_SIZE:-0}

EPHEMERAL_RAID_SWAP_PARTITION=${EPHEMERAL_RAID_SWAP_PARTITION:-}
EPHEMERAL_RAID_FS_PARTITION=${EPHEMERAL_RAID_FS_PARTITION}





is_true() {
    if [ "x$1" = "xtrue" -o "x$1" = "xyes" -o "x$1" = "x0" ] ; then
       return 0
    else
        return 1
    fi
}

autodiscover_ephemeral_by_metadata() {
        EPHEMERAL_DISK_COUNT=0
        EPHEMERAL_DISKS=''
        CMD='curl -qs http://169.254.169.254/latest/meta-data/block-device-mapping/'
        local ephemeral_disks=$(${CMD} | grep ephemeral)
        if [ -z "${ephemeral_disks}" ]; then
            ${logger} "FAILED TO START: No Ephemeral disks found;"
            exit 0
        fi
        for disk in ${ephemeral_disks}; do 
            local diskname=$( ${CMD}/${disk})
            EPHEMERAL_DISKS="${EPHEMERAL_DISKS} /dev/${diskname/sd/xvd}"
            EPHEMERAL_DISK_COUNT=$(( ${EPHEMERAL_DISK_COUNT}+1 ))
        done
}

mk_raid() {
    if [ ! -e ${MDADM} ]; 
        ${logger} "FAILED TO START; missing ${MDADM}"
        exit 5
    fi;
    $MDADM --create ${EPHEMERAL_RAID_DEVICE_NAME} ${EPHEMERAL_RAID_LEVEL} --chunk=1024 --name="${EPHEMERAL_RAID_DEVICE_NAME} " --raid-devices=${EPHEMERAL_DISK_COUNT}
}


mk_swap () {
    MKSWAP=$(which mkswap)
    if is_true "$EPHEMERAL_RAID_SWAP"  && [ ! -z "${EPHEMERAL_RAID_SWAP_PARTITION}" ]; then
        mk_partition ${EPHEMERAL_RAID_SWAP_PARTITION} 
        ${MKSWAP} ${EPHEMERAL_RAID_SWAP_PARTITION}
        activate_swap
    else
        ${logger} "Ephemeral swap skipped"
    fi
}


mk_fs () {
    ${logger} "format of ${EPHEMERAL_RAID_FS_PARTITION} start"
    ${EPHEMERAL_RAID_FS_FORMAT}  ${EPHEMERAL_RAID_FS_PARTITION} > /dev/null 2>&1 && \
        ${logger} "format of ${EPHEMERAL_RAID_FS_PARTITION} complete"  || \
        ${logger} "FAILURE: format of ${EPHEMERAL_RAID_FS_PARTITION} was not successful"
}


mk_partition () {
    DEVICE=$1
    SIZE=${2:-'-1'}
    PARTED='/sbin/parted'
    if [ -z "${PARTED}" ]; then
        ${logger} "FAILED TO START: partitioning was configured, however, the executable 'parted' was not found; cannot partition"
        exit 5
    fi
    # backup partition table:
    ${PARTED} --script --machine ${DEVICE} print > /var/tmp/${DEVICE}.parted  
    local PART_START_POS=1
    ${PARTED} ${DEVICE} --script -- mklabel msdos
    ${PARTED} ${DEVICE} --script -- unit MB mkpart primary ${PART_START_POS} ${SIZE}
    ${PARTED} ${DEVICE} --script print
}


mount_partition() {
    MNT=$(which mount)
    ${MNT}  ${EPHEMERAL_RAID_FS_PARTITION} ${EPHEMERAL_RAID_FS_MOUNT_POINT} || ${logger} "failed to mount"

}

activate_swap() {
    if 
    /sbin/swapon ${EPHEMERAL_RAID_SWAP_PARTITION} 
    retval=$?
    if [ $? -ne 0 ]; then
        log_daemon_msg "FAILURE: Swap ${EPHEMERAL_RAID_SWAP_PARTITION} failed to activate";
        echo_fail
        exit 1
    fi
    log_daemon_msg "Swap ${EPHEMERAL_RAID_SWAP_PARTITION} activated" 
    echo_ok
    return retval
}



start() {

    if [ -z $EPHEMERAL_DISKS ]; then
        autodiscover_ephemeral_by_metadata
    fi

    log_daemon_msg $"Starting $prog: "
    mk_raid
    mk_swap
    mk_partition  "$EPHEMERAL_RAID_DEVICE"
    mk_fs
    mount_partition
    RETVAL=$?
    if [ RETVAL -ne 0 ]; then
        echo_fail
        exit 1
    fi

    if [ $retval -eq 0 ]; then
        touch $lockfile
    fi
    echo_ok
    return $RETVAL
}

stop() {
    echo -n $"Shutting down $prog: "
    # No-op
    RETVAL=7
    return $RETVAL
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
    restart|try-restart|condrestart)
        ## Stop the service and regardless of whether it was
        ## running or not, start it again.
        # 
        ## Note: try-restart is now part of LSB (as of 1.9).
        ## RH has a similar command named condrestart.
        # THIS IS A DESTRUCTIVE PROCESS
        RETVAL=3
        ;;
    reload|force-reload)
        # It does not support reload
        RETVAL=3
        ;;
    status)
        echo -n $"Checking for service $prog:"
        # Return value is slightly different for the status command:
        # 0 - service up and running
        # 1 - service dead, but /var/run/  pid  file exists
        # 2 - service dead, but /var/lock/ lock file exists
        # 3 - service not running (unused)
        # 4 - service status unknown :-(
        # 5--199 reserved (5--99 LSB, 100--149 distro, 150--199 appl.)
        RETVAL=3
        ;;
    *)
        echo "Usage: $0 {start|stop|status|try-restart|condrestart|restart|force-reload|reload}"
        RETVAL=3
        ;;
esac

exit $RETVAL


BLOCKDEV=/dev/md1

#mdadm --create --verbose ${BLOCKDEV} --level=0 --chunk=1024 --name=Vertica-ephemeral-2disk-raid0  --raid-devices=2 /dev/xvdba /dev/xvdbb
#ALIGN_OPT=$(cat /sys/block/${BLOCKDEV##*/}/queue/optimal_io_size)
#ALIGN_MINIO=$(cat /sys/block/${BLOCKDEV##*/}/queue/minimum_io_size)
#ALIGN_BLKSZ=$(cat /sys/block/${BLOCKDEV##*/}/queue/physical_block_size)
#PART_START_POS=$(( $ALIGN_OPT / $ALIGN_BLKSZ ))
parted ${BLOCKDEV} --script -- mklabel msdos
parted ${BLOCKDEV} --script -- mkpart primary ${PART_START_POS}s -1
parted ${BLOCKDEV} --script print
mkfs.ext4 ${BLOCKDEV}p1
mkdir /srv/vertica-temp/; 
mount ${BLOCKDEV}p1 /srv/vertica-temp/
mkdir /srv/vertica-temp/data;
chown dbadmin /srv/vertica-temp/data; 
mdadm --detail --scan ${BLOCKDEV} >> /tmp/mdadm.conf
