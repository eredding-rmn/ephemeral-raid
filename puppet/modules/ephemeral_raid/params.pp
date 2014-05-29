# Class: ephemeral_raid::params
#
#
class ephemeral_raid::params {
    # resources
    # install stuff
    # with the package undefined, we use the file
    $package_name              = undef
    $package_ensure            = 'installed'

    # service stuff
    $service_name = "ephemeral-raid"
    $service_ensure = "running"
    $service_enable = "true"

    # config stuff
    $mdadm_path                = "/sbin/mdadm"
    # list of disks expected to be allocated, otherwise, will be discovered.
    $ephemeral_disks           = undef
    $ephemeral_disk_count      = undef
    $raid_device_name          = "ephemeral-raid0"
    $raid_options              = "--chunk=1024"
    $raid_level                = "0"
    $raid_device               = "/dev/md99"
    $raid_fs_partition         = "${raid_device}p2"
    $raid_fs_mount_point       = "/srv/data"
    $raid_fs_mount_point_owner = "root"
    $raid_fs_mount_point_group = "root"
    $raid_fs_mount_point_mode  = "0755"
    $raid_fs_format_command    = "mkfs.ext4"
    # ephemeral_swap_allocated is a string, not a bool
    $ephemeral_swap_allocated  = "false"
    $swap_space_in_mb          = "4096"
    $swap_partition            = "${raid_device}p1"

    case $::osfamily {
        "debian": {
            $defaults_file = "/etc/defaults/ephemeral_raid"
        }
        "redhat": {  
            $defaults_file = "/etc/sysconfig/ephemeral_raid"   
        }
    }
}