Exec {
    path => "/sbin:/bin:/usr/sbin:/usr/bin",
}

Package {
    require => Exec["yum clean all"],
}

include bootstrap

class bootstrap {
    file { "/etc/yum.repos.d/puppet.repo":
        ensure => file,
        owner  => "root",
        group  => "root",
        mode   => 0644,
        source => "file:///root/puppet-bootstrap/puppet.repo",
        notify => Exec["yum clean all"],
    }

    package { "epel-release":
        ensure   => present,
        provider => rpm,
        source   => "http://download.fedoraproject.org/pub/epel/${lsbmajdistrelease}/${architecture}/epel-release-5-4.noarch.rpm",
        require  => undef,
        notify   => Exec["yum clean all"],
    }

    exec { "yum clean all":
        command     => "yum clean all",
        refreshonly => true,
    }

    package { "puppet-server":
        ensure => present,
    }

    package { "httpd":
        ensure => present,
    }

    package { "mod_ssl":
        ensure => present,
    }

    package { "rubygem-rack":
        ensure => present,
    }

    # This should possibly be a dependency of rubygem-passenger as things
    # like passenger-status don't work without it
    package { "rubygem-rake":
        ensure => present,
    }

    package { "rubygem-passenger":
        ensure => present,
    }

    file { "/etc/httpd/conf.d/passenger.conf":
        ensure  => file,
        owner   => "root",
        group   => "root",
        mode    => 0644,
        source  => "file:///root/puppet-bootstrap/passenger.conf",
        require => [
            Package["httpd"],
            Package["rubygem-passenger"],
        ],
        notify  => Service["httpd"],
    }

    file { "/etc/httpd/conf.d/puppetmasterd.conf":
        ensure  => file,
        owner   => "root",
        group   => "root",
        mode    => 0644,
        content => template("puppetmasterd.conf.erb"),
        require => Package["httpd"],
        notify  => Service["httpd"],
    }

    file { "/srv/www":
        ensure => directory,
        owner  => "root",
        group  => "root",
        mode   => 0644,
    }

    file { "/srv/www/puppet.${domain}":
        ensure  => directory,
        owner   => "root",
        group   => "root",
        mode    => 0644,
        require => File["/srv/www"],
    }

    file { "/srv/www/puppet.${domain}/public":
        ensure  => directory,
        owner   => "root",
        group   => "root",
        mode    => 0644,
        require => File["/srv/www/puppet.${domain}"],
    }

    file { "/srv/www/puppet.${domain}/tmp":
        ensure  => directory,
        owner   => "root",
        group   => "root",
        mode    => 0644,
        require => File["/srv/www/puppet.${domain}"],
    }

    file { "/srv/www/puppet.${domain}/config.ru":
        ensure  => file,
        owner   => "puppet",
        group   => "root",
        mode    => 0644,
        source  => "file:///root/puppet-bootstrap/config.ru",
        require => [
            File["/srv/www/puppet.${domain}"],
            File["/srv/www/puppet.${domain}/public"],
            File["/srv/www/puppet.${domain}/tmp"],
            Package["rubygem-rack"],
        ],
        notify  => Service["httpd"],
    }

    file { "/etc/puppet/puppet.conf":
        ensure  => file,
        owner   => "root",
        group   => "root",
        mode    => 0644,
        content => template("puppet.conf.erb"),
        require => Package["puppet-server"],
        notify  => Service["httpd"],
    }

    service { "puppetmaster":
        ensure     => stopped,
        enable     => false,
        hasrestart => true,
        hasstatus  => true,
        require    => Package["puppet-server"],
    }

    # Short of a nice way to get the certificates generated just start up
    # puppetmaster and stop it again
    exec { "puppetmaster-run-once":
        command => "service puppetmaster start && service puppetmaster stop",
        creates => "/var/lib/puppet/ssl/certs/puppet.${domain}.pem",
        require => Service["puppetmaster"],
    }

    service { "httpd":
        ensure     => running,
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        require    => [
            Package["httpd"],
            Package["mod_ssl"],
            Exec["puppetmaster-run-once"],
        ],
    }
}
