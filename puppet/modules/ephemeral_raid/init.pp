# Class: ephemeral_raid
#
#
class ephemeral_raid (
) inherits ephemeral_raid::params{
    class{'ephemeral_raid::install': }
    class{'ephemeral_raid::config': }
    class{'ephemeral_raid::service': }
    Class['ephemeral_raid::install'] ->  Class['ephemeral_raid::configure'] -> Class['ephemeral_raid::service']
}