# Class: ephemeral_raid::service()
#
#
class ephemeral_raid::service(
$service_name = $ephemeral_raid::service_name,
$service_enabled = $ephemeral_raid::service_enabled,
$service_ensure = $ephemeral_raid::service_ensure,
$raid_device = $ephemeral_raid::raid_device
) {
    service { "${service_name}":
        enable => $service_enabled,
        ensure => $service_ensure,
        hasrestart => false
    }
}