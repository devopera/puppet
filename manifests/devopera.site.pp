#
# SENSITIVE: this file contains passwords (hashed and plaintext)
#
node default {

  #
  # global config
  #
  case $operatingsystem {
    centos, redhat: {
      $selinux = true
    }
    ubuntu, debian: {
      $selinux = false
    }
  }

  class { 'prerun' :
    stage => 'first',
  }
 
  class { 'postrun' :
    stage => 'last',
  }

  class { 'docommon' :
    ssh_password_authentication => 'yes',
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
  
  #
  # profile-specific config based on client-side custom facts
  #
  $profile_components = split($server_profile, ' ')
  process_profile{ $profile_components : 
    require => Class['docommon'],
  }
}

define process_profile (
  $profile = $name,
  $user = 'web',
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
    }
    desktop: {
      # install X Windows
      class { 'docommon::desktop' : }
    }
    django-14: {
      class { 'dodjango' :
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
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
      }
    }
    drupal-8: {
      class { 'dodrupal' :
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
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
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
    nagios-target: {
      class { 'donagios' : }
    }
    nagios-3: {
      class { 'donagios::server' :
        user => $user,
        webadmin_limitlocalhost => false,
        require => [Class['dozendserver']],
      }
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
        # set this machine up as its own puppetmaster
        master_use_original => false,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }
    }
    production: {
      # remove autoload key password once key loaded for puppet
      class { 'dopki::sshagentcleanup' :
        require => Class['dopki::sshagentadd'],
      }
      class { 'docsf':
        require => Class['docommon'],
      }
      class { 'rkhunter':
        require => Class['docommon'],
      }
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

