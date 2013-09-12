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
      # add vagrant's low-security key for ssh key auth
      dopki::addkey { 'dopki-vagrant' :
        user => $user,
        user_email => $user_email,
        # vagrant insecure public key
        key_public => 'AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ==',
        key_private_type => 'rsa',
        key_private_name => 'id_rsa_vagrant',
        # vagrant insecure private key
        key_private => '-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzI
w+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoP
kcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2
hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NO
Td0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcW
yLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQIBIwKCAQEA4iqWPJXtzZA68mKd
ELs4jJsdyky+ewdZeNds5tjcnHU5zUYE25K+ffJED9qUWICcLZDc81TGWjHyAqD1
Bw7XpgUwFgeUJwUlzQurAv+/ySnxiwuaGJfhFM1CaQHzfXphgVml+fZUvnJUTvzf
TK2Lg6EdbUE9TarUlBf/xPfuEhMSlIE5keb/Zz3/LUlRg8yDqz5w+QWVJ4utnKnK
iqwZN0mwpwU7YSyJhlT4YV1F3n4YjLswM5wJs2oqm0jssQu/BT0tyEXNDYBLEF4A
sClaWuSJ2kjq7KhrrYXzagqhnSei9ODYFShJu8UWVec3Ihb5ZXlzO6vdNQ1J9Xsf
4m+2ywKBgQD6qFxx/Rv9CNN96l/4rb14HKirC2o/orApiHmHDsURs5rUKDx0f9iP
cXN7S1uePXuJRK/5hsubaOCx3Owd2u9gD6Oq0CsMkE4CUSiJcYrMANtx54cGH7Rk
EjFZxK8xAv1ldELEyxrFqkbE4BKd8QOt414qjvTGyAK+OLD3M2QdCQKBgQDtx8pN
CAxR7yhHbIWT1AH66+XWN8bXq7l3RO/ukeaci98JfkbkxURZhtxV/HHuvUhnPLdX
3TwygPBYZFNo4pzVEhzWoTtnEtrFueKxyc3+LjZpuo+mBlQ6ORtfgkr9gBVphXZG
YEzkCD3lVdl8L4cw9BVpKrJCs1c5taGjDgdInQKBgHm/fVvv96bJxc9x1tffXAcj
3OVdUN0UgXNCSaf/3A/phbeBQe9xS+3mpc4r6qvx+iy69mNBeNZ0xOitIjpjBo2+
dBEjSBwLk5q5tJqHmy/jKMJL4n9ROlx93XS+njxgibTvU6Fp9w+NOFD/HvxB3Tcz
6+jJF85D5BNAG3DBMKBjAoGBAOAxZvgsKN+JuENXsST7F89Tck2iTcQIT8g5rwWC
P9Vt74yboe2kDT531w8+egz7nAmRBKNM751U/95P9t88EDacDI/Z2OwnuFQHCPDF
llYOUI+SpLJ6/vURRbHSnnn8a/XG+nzedGH5JGqEJNQsz+xT2axM0/W/CRknmGaJ
kda/AoGANWrLCz708y7VYgAtW2Uf1DPOIYMdvo6fxIB5i9ZfISgcJ/bbCUkFrhoH
+vq/5CIWxCPp0f85R4qxxQ5ihxJ0YDQT9Jpx4TMss4PSavPaBH3RXow5Ohe+bYoQ
NE5OgEXk2wVfZczCZpigBKbKZHNYcelXtTt/nP3rsCuGcM4h53s=
-----END RSA PRIVATE KEY-----',
        # lowsec key does not prompt for passphrase
        key_private_passphrase => '',
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
        # set this machine up as its own puppetmaster, i.e. not use original
        master_use_original => false,
        require => Class['dorepos'],
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

