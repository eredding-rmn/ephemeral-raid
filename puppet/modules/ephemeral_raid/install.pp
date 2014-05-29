# Class: ephemeral_raid::install 
#
#
class ephemeral_raid::install  (
    $package_name   =  $ephemeral_raid::package_name,
    $package_ensure = $ephemeral_raid::package_ensure
) {
    # resources

    if $package_name {
        package { "${package_name}":
            ensure => $package_ensure,
        }
    } else {
        file { "/etc/init.d/ephemeral-raid":
            ensure => file,
            source => puppet:///modules/ephemeral_raid/ephemeral_raid.init
            mode => 0755
        }
    }
}