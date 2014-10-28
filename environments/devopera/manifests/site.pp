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
    server_version => '6.3',
    php_version => '5.4',
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
      server_version => '6.3',
      php_version => '5.4',
    }
  }
}


define process_profile (
  $profile = $name,
  $user = 'web',
  $group = 'www-data',
  $user_email = 'admin@example.com',
  $ssh_port = 15022,
) {
  # output status message
  notify { "processing profile component: ${profile}": }

  # match this profile component against known profiles
  case $profile {
    dev: {
      # include gcc first to avoid later package conflict
      class { 'gcc': }->
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
    }
    derbyjs: {
      if ! defined(Class['doyeoman']) {
        class { 'doyeoman' :
          user => $user,
          require => [Class['donodejs']],
        }
      }
      class { 'domean' :
        user => $user,
        require => [Class['docommon'], Class['dozendserver'], Class['dorepos']],
      }->
      class { 'redis' :
        # @todo version number needs to be advanced by hand
        version => '2.6.14',
      }
      class { 'doderby' :
        user => $user,
        require => [Class['donodejs'], Class['redis'], Class['doyeoman']],
      }->
      doderby::base { 'derby-demo' :
        user => $user,
        symlinkdir => "/home/${user}",
      }
      # also install yeoman for boilerplates
      if ! defined(Class['doyeoman']) {
        class { 'doyeoman' :
          user => $user,
          require => [Class['donodejs']],
        }
      }
    }
    desktop: {
      # install X Windows
      class { 'docommon::desktop' : }
    }
    django-1-official: {
      # required profiles: python-27/python-33
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
      # required profiles: python-27/python-33
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
        app_name => 'drupal-7',
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
        app_name => 'drupal-8.x',
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
      }
      dodrupal::base { 'dodrupal-base-7' :
        user => $user,
        vhost_seq => '02',
        app_name => 'drupal-7',
        monitor => true,
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb'], Class['dodrupal']],
      }
    }
    jekyll: {
      if ! defined(Class['donodejs']) {
        class { 'donodejs' :
          user => $user,
          require => [Class['docommon'], Class['dozendserver'], Class['dorepos']],
        }
      }
      class { 'dojekyll' :
        user => $user,
        require => [Class['donodejs']],
      }
    }
    lamp: {
      # install simple demo of LAMP stack
      dorepos::installapp { 'lamp-demo' :
        user => $user,
        repo_source => 'https://github.com/devopera/appconfig-lamp.git',
        symlinkdir => "/home/${user}/",
        install_databases => true,
        require => [Class['dorepos'], Class['domysqldb']],
      }
    }
    mean: {
      class { 'domean' :
        user => $user,
        require => [Class['docommon'], Class['dozendserver'], Class['dorepos']],
      }->
      domean::base { 'mean-demo' :
        user => $user,
        symlinkdir => "/home/${user}",
      }
      # also install yeoman for boilerplates
      if ! defined(Class['doyeoman']) {
        class { 'doyeoman' :
          user => $user,
          require => [Class['donodejs']],
        }
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
    nodejs: {
      if ! defined(Class['donodejs']) {
        class { 'donodejs' :
          user => $user,
          require => [Class['docommon'], Class['dozendserver'], Class['dorepos']],
        }
      }
      donodejs::base { 'hellonode' :
        user => $user,
        symlinkdir => "/home/${user}",
        require => [Class['donodejs']],
      }
    }
    nagios: {
      class { 'donagios' : }
      if ($server_profile =~ /dev/) {
        # if both nagios and dev profiles present
        class { 'donagios::nrpe-client' :
          # cover clients with and without subnet (/24) wildcard support
          allowed_hosts => [ '127.0.0.1', '10.12.2.0/24', '10.12.2.160', ],
        }
      }
    }
    nagios-server-3: {
      class { 'donagios::server::pre' :
      }->
      class { 'donagios::nrpe-client' :
        allowed_hosts => [ '127.0.0.1', '10.12.2.0/24', '10.12.2.160', ],
      }->
      class { 'donagios::server' :
        user => $user,
        webadmin_limitlocalhost => false,
        require => [Class['dozendserver']],
      }
      # setup hostgroup
      nagios_hostgroup { 'devopera': }
    }
    phonegap: {
      # required profiles: desktop
      if ! defined(Class['donodejs']) {
        class { 'donodejs' :
          user => $user,
          require => [Class['docommon'], Class['dozendserver'], Class['dorepos']],
        }
      }
      class { 'dophonegap' :
        user => $user,
        group => $group,
        require => [Class['donodejs'], Class['docommon::desktop']],        
      }
    }
    puppetmaster: {
      # install Postgresql for puppetdb
      if ! defined(Class['dopostgresql']) {
        class { 'dopostgresql' :
          before => Class['dopuppetmaster'],
        }
      }
      # replace local /etc/puppet directory with repo, but merge in agent/master settings
      class { 'dopuppetmaster' :
        user => $user,
        # setup puppetmaster with devopera-puppet open repo
        puppet_repo_source => 'https://github.com/devopera/puppet.git',
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
    python-33: {
      # install python in virtualenv
      class { 'dopython' :
        version_python_major => '3.3',
        version_python_minor => '4',
        require => Class['docommon'],
      }->
      class { 'dopython::wsgi' :
        version_python_major => '3.3',
        require => Class['dozendserver'],
      }
    }
    redmine-2: {
      # install passenger
      class { 'dopassenger' :
        require => [Class['docommon'], Class['dozendserver']],
      }->
      # install Redmine deps
      class { 'doredmine' :
        user => $user,
      }->
      doredmine::base { 'redmine' :
        user => $user,
        monitor => true,
        db_populate => true,
        symlinkdir => "/home/${user}",
        require => [Class['dorepos'], Class['dozendserver'], Class['domysqldb']],
      }->
      # install vhost for redmine base
      dorepos::installapp { 'redmine-demo' :
        user => $user,
        refresh_apache_type => 'restart',
        repo_source => 'https://github.com/devopera/appconfig-redmine.git',
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
      dosymfony::base { 'dosymfony-demo':
        user => $user,
        monitor => true,
        symlinkdir => "/home/${user}",
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
    yeoman : {
      if ! defined(Class['donodejs']) {
        class { 'donodejs' :
          user => $user,
          require => [Class['docommon'], Class['dozendserver'], Class['dorepos']],
        }
      }
      if ! defined(Class['doyeoman']) {
        class { 'doyeoman' :
          user => $user,
          require => [Class['donodejs']],
        }
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
  # output date/time for keeping track
  exec { 'main-output-date-time' :
    command => '/bin/date',
    logoutput => true,
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
