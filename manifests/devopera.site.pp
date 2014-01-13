#
# SENSITIVE: this file contains passwords (hashed and plaintext)
#
node default {

  class { 'prerun' :
    stage => 'first',
  }
 
  class { 'postrun' :
    stage => 'last',
  }

  # put all machines puppeted in this environment into a hostgroup
  Nagios_host {
    hostgroups => ['devopera'],
  }

  class { 'docommon' :
    ssh_password_authentication => 'yes',
    firewall_module => 'example42',
  }
  # tell all fireports to use example42's firewall -> iptables module(s)
  Docommon::Fireport {
    firewall_module => 'example42',
  }

  class { 'dopki' :
    require => Class['docommon'],
  }

  class { 'dorepos' :
    require => [Class['dopki'],Class['dopki::sshagentadd']],
  }

  class { 'dozendserver' :
    require => Class['docommon'],
  }

  class { 'domysqldb' :
    require => Class['docommon'],
  }

  class { 'ntp' : 
  }

  class { 'domotd' :
    use_dynamics => true,
  }

  # secure email sending with no local delivery
  class { 'dopostfix' :
  }

  # puppi for deps, deployments and nagios plugins
  class { 'puppi' : }
  
  #
  # profile-specific config based on client-side custom facts
  #
  $profile_components = split($server_profile, ' ')
  process_profile{ $profile_components : 
    require => Class['docommon'],
  }

  #
  # profile-specific defaults, which must be set in the default node
  #
  if ($server_profile =~ /django-1-beta/) {
    class { 'dozendserver::override':
      server_version => '6.1',
      php_version => '5.4',
    }
  }
}


define process_profile (
  $profile = $name,
  $user = 'web',
  $user_email = 'admin@example.com',
  $ssh_port = 15022,
) {
  # output status message
  notify { "processing profile component: ${profile}": }

  # match this profile component against known profiles
  case $profile {
    dev: {
      class { 'docommon::dev' : }
      # set apache/PHP to show errors
      class { 'dozendserver::debug' : }
      # install samba with default password
      class { 'dosamba' :
        require => [Class['dorepos']],
      }
      # overwrite sudo config to allow passwordless sudo
      sudo::conf { "${user}-dev":
        priority => 20,
        content  => "${user} ALL = NOPASSWD: ALL\nDefaults:${user}    !requiretty\nDefaults:${user}    visiblepw",
      }
      # open up direct database access
      class { 'domysqldb::dev' : }
      # add vagrant's low-security key for ssh key auth
      class { 'dopki::vagrant' :
        user => $user,
        user_email => $user_email,
      }
      package { 'jekyll':
        ensure   => 'installed',
        provider => 'gem',
        require  => [Class['docommon::dev']],
      }
    }
    desktop: {
      # install X Windows
      class { 'docommon::desktop' : }
    }
    django-1-official: {
      class { 'dodjango' :
        require => Class['dopython'],
      }->
      class { 'dodjango::base' :
        user => $user,
        monitor => true,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }
    }
    django-1-beta: {
      class { 'dodjango' :
        release => 'beta',
        release_branch => '1.6.x',
        require => Class['dopython'],
      }->
      class { 'dodjango::base' :
        user => $user,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }
    }
    drupal-7: {
      class { 'dodrupal' :
        require => Class['docommon'],
      }
      dodrupal::base { 'dodrupal-base-7' :
        user => $user,
        version => 'drupal-7',
        monitor => true,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
      }
    }
    drupal-8: {
      class { 'dodrupal' :
        version => 'master',
        require => Class['docommon'],
      }
      dodrupal::base { 'dodrupal-base-8.x' :
        user => $user,
        vhost_seq => '01',
        version => 'drupal-8.x',
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
      }
      dodrupal::base { 'dodrupal-base-7' :
        user => $user,
        vhost_seq => '02',
        version => 'drupal-7',
        monitor => true,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
      }
    }
    lamp: {
      # install simple demo of LAMP stack
      dorepos::installapp { 'lamp-demo' :
        user => $user,
        repo => {
          provider => 'git',
          path => '/var/www/git/github.com',
          source => 'https://github.com/devopera/appconfig-lamp.git',
        },
        symlinkdir => "/home/${user}/",
        install_databases => true,
        require => [Class['dorepos'], Class['domysqldb']],
      }
    }
    mantisbt-1: {
      class { 'domantis' :
        require => Class['docommon'],
      }->
      class { 'domantis::base' :
        user => $user,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }
    }
    nagios: {
      class { 'donagios' : }
      if ($server_profile =~ /dev/) {
        # if both nagios and dev profiles present
        class { 'donagios::nrpe-client' : }
      }
    }
    nagios-server-3: {
      class { 'donagios::server::pre' :
      }->
      class { 'donagios::server' :
        user => $user,
        webadmin_limitlocalhost => false,
        require => [Class['dozendserver']],
      }
      # setup hostgroup
      nagios_hostgroup { 'devopera': }
    }
    puppetmaster: {
      # replace local /etc/puppet directory with repo, but merge in agent/master settings
      class { 'dopuppetmaster' :
        user => $user,
        # setup puppetmaster with devopera-puppet open read-only repo
        puppet_repo => {
          provider => 'git',
          path => '/etc/puppet',
          source => 'https://github.com/devopera/puppet.git',
        },
        environments => {
          'production' => {
             comment => 'production is the default environment',
             manifest => '$confdir/manifests/devopera.site.pp',
          },
          'devopera' => {
             comment => 'for all devopera VMs and builds',
             manifest => '$confdir/manifests/devopera.site.pp',
          },
        },
        # set this machine up as its own puppetmaster, i.e. not use original
        master_use_original => false,
        require => Class['dorepos'],
      }
    }
    production: {
      # no production profile in devopera
    }
    python-27: {
      # install python in virtualenv
      class { 'dopython' :
        require => Class['docommon'],
      }->
      class { 'dopython::wsgi' :
        require => Class['dozendserver'],
      }
    }
    redmine-2: {
      class { 'doredmine' :
        require => Class['docommon'],
      }->
      class { 'doredmine::base' :
        user => $user,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }
    }
    squid-server: {
      # setup squid server and expose port
      class { 'dosquid::server':
        cache_dir_size_gb => 100, # 100GB cache
        require => Class['docommon'],
      }
    }
    symfony-2: {
      # install symfony demo and composer
      class { 'dosymfony':
        require => [Class['dozendserver']],
      }->
      class { 'dosymfony::base':
        user => $user,
      }
    }
    updates: {
      # install secure update user
      class { 'doupdates' :
        key_private_passphrase => 'sdkkg835%*&dd*zz41i',
        require => Class['docommon'],
      }
    }
    wordpress-3: {
      class { 'dowordpress' :
        require => Class['docommon'],
      }->
      class { 'dowordpress::base' :
        user => $user,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }
    }
    default: {
      # return an error message and stop
      fail("${::hostname}: trying to puppet a '${profile}' profile that does not exist")
    }
  }
}

# introduce pre-run (first) and post-run (last) stages
stage { 'first' : 
  before => Stage['main'],
}
stage { 'last' : }
Stage['main'] -> Stage['last']

class prerun (

) {
  # if squid caching module installed
  if defined('dosquid') {
    # setup yum/wget to use squid (if server pingable)
    class { 'dosquid' :
      squid_ip => '10.12.1.130',
    }
  }
}

class postrun (

) {
  # if squid caching module installed
  if defined('dosquid') {
    # tell yum/wget not to use squid cache
    class { 'dosquid::cleanup' : }
  }
}

