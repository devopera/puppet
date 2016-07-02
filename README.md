puppet
======

Base repository containing simple manifest and references to all submodules

Installation
------------
This is a clone of the devopera/puppet module.  It features everything you need to start puppetting from this machine as a puppetmaster.  This is a clone of a read-only repo, so the first thing you should do is fork the repo and start saving modifications to your own remote.  A full explanation is available on StackOverflow:

http://stackoverflow.com/questions/4209208/how-to-convert-a-readonly-git-clone-from-github-to-a-forked-one

Please start by creating your own fork of this repo:

https://github.com/devopera/puppet

New client setup
----------------

To setup a new or freshly installed machine as a puppet agent (client) from scratch:

1. Perform a minimal install of the OS (e.g. Centos 6)

2. Install Puppet 3 (agent) using Puppetlabs rpm/deb repositories
Under Centos 6
```
su
rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
yum -y update
yum -y install puppet
```
Under Centos 7
```
su
rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-7.noarch.rpm
yum -y update
yum -y install puppet
```
Under Fedora (17 & 18)
```
su
sudo rpm -ivh http://yum.puppetlabs.com/fedora/f17/products/i386/puppetlabs-release-17-6.noarch.rpm
yum -y update
yum -y install puppet
```
Under Ubuntu 12.04 LTS
```
wget http://apt.puppetlabs.com/puppetlabs-release-precise.deb
sudo dpkg -i puppetlabs-release-precise.deb
sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get install puppet
```

Under Ubuntu 14.04 LTS
```
wget http://apt.puppetlabs.com/puppetlabs-release-trusty.deb
sudo dpkg -i puppetlabs-release-trusty.deb
sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get install puppet
```

3. Point the agent at the Puppet master (using puppet alias for machine-name.lan)
```
    <add puppet master to /etc/hosts>
    e.g. <ip address> puppet
```
3b. [Optionally] set the environment for this agent in /etc/puppet/puppet.conf.  Production is the default.
```
    environment = production
```
3c. [Optionally] set the profile for this machine in /etc/puppet/puppet.conf
```
    pluginsync = true
```
and in /etc/puppet/custom_facts.yml (default is <none>)
```
    server_profile: dev
```
3d. For local Virtualbox VMs, force the hostname from .lan to .localdomain.  This creates VMware/Virtualbox symmetry and negates the need for two puppet certs, but remember that Virtualbox (bridged networking) can't access other subnets (e.g. puppet master).
```
    hostname <hostname>.localdomain
```
4. Test the agent and send cert to server
```
    puppet agent -dvt
```
5. On Server, sign the certificate
```
    puppet cert sign "<client-fqdn>"
```
6. Run the agent properly for the first time
```
    puppet agent -dvt
```
7. Log out and log back in again to trigger ssh-add, or
```
    source .bashrc
```

At this stage it's also worth adding acl to /etc/fstab and setting up SELinux.
