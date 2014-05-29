# Class: ephemeral_raid::config ()
#
#
class ephemeral_raid::config (
    $defaults_file             = $ephemeral_raid::defaults_file,
    $mdadm_path                = $ephemeral_raid::mdadm_path,
    $ephemeral_disks           = $ephemeral_raid::ephemeral_disks,
    $ephemeral_disk_count      = $ephemeral_raid::ephemeral_disk_count,
    $raid_device_name          = $ephemeral_raid::raid_device_name,
    $raid_options              = $ephemeral_raid::raid_options,
    $raid_level                = $ephemeral_raid::raid_level,
    $raid_device               = $ephemeral_raid::raid_device,
    $raid_fs_partition         = $ephemeral_raid::raid_fs_partition,
    $raid_fs_mount_point       = $ephemeral_raid::raid_fs_mount_point,
    $raid_fs_mount_point_owner = $ephemeral_raid::raid_fs_mount_point_owner,
    $raid_fs_mount_point_group = $ephemeral_raid::raid_fs_mount_point_group,
    $raid_fs_mount_point_mode  = $ephemeral_raid::raid_fs_mount_point_mode,
    $raid_fs_format_command    = $ephemeral_raid::raid_fs_format_command,
    $ephemeral_swap_allocated  = $ephemeral_raid::ephemeral_swap_allocated,
    $swap_space_in_mb          = $ephemeral_raid::swap_space_in_mb,
    $swap_partition            = $ephemeral_raid::swap_partition
) {
    # resources
    file { "${defaults_file}":
        ensure => file,
        content => template('ephemeral_raid/ephemeral_raid_defaults.erb'),
    }
}