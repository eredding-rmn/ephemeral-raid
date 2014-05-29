# EPHEMERAL-RAID

Set up your AWS EC2 Ephemeral disks on boot!

# Usage
* copy ephemeral-raid.sh to /etc/init.d/ephemeral-raid, set it executable
* copy ephemeral-raid-defaults to either /etc/defaults/ephemeral-raid or /etc/sysconfig/ephemeral-raid
* modify the defaults file to your liking 

## note
* if EPHEMERAL_RAID_LEVEL isn't sane [see this RAID setup](https://raid.wiki.kernel.org/index.php/RAID_setup), this will explode; there is no sanity check because there's an expectation that you *know* how to use mdadm if you're using this
* the above rule applies for most settings... so don't set any of the following to be a symlink to the sun :sunny: or to /dev/null: EPHEMERAL_RAID_DEVICE, EPHEMERAL_RAID_FS_MOUNT_POINT, EPHEMERAL_RAID_FS_PARTITION, EPHEMERAL_RAID_SWAP_PARTITION.  
* only use static or dynamic discovery for a single raid device!  This is done through setting or not setting both EPHEMERAL_DISKS and EPHEMERAL_DISK_COUNT; if either of those are set, you're using static configuration.  Unset both for dynamic config.
* EPHEMERAL_RAID_FS_PARTITION is not used if EPHEMERAL_RAID_SWAP==false; it formats EPHEMERAL_RAID_DEVICE
* EPHEMERAL_RAID_SWAP == true requires:
 * EPHEMERAL_RAID_SWAP_SIZE
 * EPHEMERAL_RAID_SWAP_PARTITION
 * _AND_ EPHEMERAL_RAID_FS_PARTITION


# todo
* remove partitioning and force-jam lvm in yo face (would have saved the scripted parted woes *doh* )
* packaging scripts (see fpm for immediate loving)
* tools around validation of functionality
* config management tooling 

# contributing
* pull requests welcome! 

# source
GitHub [ephemeral-raid](https://github.com/eredding-rmn/ephemeral-raid)