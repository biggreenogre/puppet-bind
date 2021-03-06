# ex: syntax=puppet si ts=4 sw=4 et

class bind (
    $confdir    = $::bind::params::confdir,
    $cachedir   = $::bind::params::cachedir,
    $forwarders = '',
    $dnssec     = true,
    $version    = '',
    $rndc       = $::bind::params::bind_rndc,
) inherits bind::params {

    $auth_nxdomain = false

    File {
        ensure  => present,
        owner   => 'root',
        group   => $::bind::params::bind_group,
        mode    => 0644,
        require => Package['bind'],
        notify  => Service['bind'],
    }

    package { 'bind':
        name   => $::bind::params::bind_package,
        ensure => latest,
    }

    file { $::bind::params::bind_files:
        ensure  => present,
    }

    if $dnssec {
        file { '/usr/local/bin/dnssec-init':
            ensure => present,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
            source => 'puppet:///modules/bind/dnssec-init',
        }
    }

    file { [ $confdir, "${confdir}/zones" ]:
        ensure  => directory,
        mode    => 2755,
        purge   => true,
        recurse => true,
    }

    file { "${confdir}/named.conf":
        content => template('bind/named.conf.erb'),
    }

    class { 'bind::keydir':
        keydir => "${confdir}/keys",
    }

    file { "${confdir}/named.conf.local":
        replace => false,
    }

    concat { [
        "${confdir}/acls.conf",
        "${confdir}/keys.conf",
        "${confdir}/views.conf",
        ]:
        owner   => 'root',
        group   => $::bind::params::bind_group,
        mode    => '0644',
        require => Package['bind'],
        notify  => Service['bind'],
    }

    concat::fragment { "named-acls-header":
        order   => '00',
        target  => "${confdir}/acls.conf",
        content => "# This file is managed by puppet - changes will be lost\n",
    }

    concat::fragment { "named-keys-header":
        order   => '00',
        target  => "${confdir}/keys.conf",
        content => "# This file is managed by puppet - changes will be lost\n",
    }

    concat::fragment { "named-keys-rndc":
        order   => '99',
        target  => "${confdir}/keys.conf",
        content => "#include \"${confdir}/rndc.key\"\n",
    }

    concat::fragment { "named-views-header":
        order   => '00',
        target  => "${confdir}/views.conf",
        content => "# This file is managed by puppet - changes will be lost\n",
    }

    service { 'bind':
        name       => $::bind::params::bind_service,
        ensure     => running,
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
    }
}
