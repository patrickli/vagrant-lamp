group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }
File { owner => 0, group => 0, mode => 0644 }

define vhost (
  $server_name    = $name,
  $docroot        = "/var/www/${name}",
  $server_aliases = '',
  $env_variables  = '',
  $dbuser         = 'root',
  $dbpass         = $::pma_mysql_root_password,
  $dbname         = regsubst($name, '\.', '_', 'G'),
  $priority       = '001',
) {
  validate_re($priority, '^\d{3}$', 'Priority must be a zero-padded 3 digit number.')
  apache::vhost { $name:
    server_name   => $name,
    serveraliases => $server_aliases,
    docroot       => $docroot,
    port          => '80',
    env_variables => $env_variables,
    priority      => $priority,
  }
  if $dbuser == 'root' {
    $real_dbpass = $::pma_mysql_root_password
  } else {
    $real_dbpass = $dbpass
  }
  mysql::db { $dbname:
    user     => $dbuser,
    password => $real_dbpass,
  }
}

define git_config (
  $value,
) {
  exec { "git config --system ${name} \"${value}\"":
    require => Package['git'],
    unless  => "test \"\$(git config ${name})\" = \"${value}\"",
  }
}

class { 'apt': }

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

apt::key { 'E1DF1F24': }
apt::key { 'A2F4C039': }

apt::ppa { 'ppa:git-core/ppa':
  require => Apt::Key['E1DF1F24']
}
apt::ppa { 'ppa:svn/ppa':
  require => Apt::Key['A2F4C039']
}

apt::conf { 'noextradeps':
  priority  => 10,
  content   => "Apt::Install-Suggests 0;\nApt::Install-Recommends 0;\nApt::AutoRemove::RecommendsImportant 0;",
}

file { '/home/vagrant/.bash_aliases':
  ensure => 'present',
  source => 'puppet:///modules/puphpet/dot/.bash_aliases',
}

package { [
    'tzdata',
    'vim',
    'curl',
    'git',
    'git-svn',
    'subversion'
  ]:
  ensure  => 'latest',
}

exec { 'autoremove':
  command     => 'apt-get autoremove --purge -y',
  refreshonly => true,
  subscribe   => Apt::Conf['noextradeps'],
}

exec { 'mysql_cleanup':
  command     => "mysql -u root --password=\"${::pma_mysql_root_password}\" -e \"DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'\" mysql",
  refreshonly => true,
  subscribe   => Class['mysql::server::account_security'],
}

exec { 'set_timezone':
  command => "echo '${::timezone}' > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata",
  unless  => "test \"\$(cat /etc/timezone)\" = \"${::timezone}\"",
  require => Package['tzdata'],
}

package { [
    'nano',
    'ubuntu-standard',
    'hdparm',
    'memtest86+',
    'parted',
    'libparted0debian1',
    'pciutils',
    'popularity-contest',
    'apparmor',
    'usbutils',
    'friendly-recovery',
    'ntfs-3g',
    'plymouth-theme-ubuntu-text',
    'ppp',
    'pppconfig',
    'pppoeconf',
    'ufw',
    'update-manager-core',
    'ed',
    'dmidecode',
    'language-selector-common'
  ]:
  ensure  => 'purged',
} -> Exec['autoremove']

tidy { '/home/vagrant/postinstall.sh': }

class { 'apache':
  process_user => 'vagrant',
}

class apache_runas {
  $file = '/etc/apache2/envvars'
  file_line { "${file}-user":
    path    => $file,
    line    => 'export APACHE_RUN_USER=vagrant',
    match   => '^export APACHE_RUN_USER',
  }
  file_line { "${file}-group":
    path    => $file,
    line    => 'export APACHE_RUN_GROUP=vagrant',
    match   => '^export APACHE_RUN_GROUP',
  }
  file { '/var/lock/apache2':
    ensure  => 'directory',
    owner   => 'vagrant',
  }
}

class { 'apache_runas':
  require => Package['apache'],
  notify  => Service['apache'],
}

apache::dotconf { 'custom':
  content => 'EnableSendfile Off',
}

apache::module { 'rewrite': }

class { 'php':
  service => 'apache',
  require => Package['apache'],
  version => 'latest',
}

php::module { 'mysql': }
php::module { 'cli': }
php::module { 'curl': }
php::module { 'intl': }
php::module { 'mcrypt': }
php::module { 'apc':
  module_prefix => 'php-',
}

class { 'xdebug':
  service => 'apache',
}

class { 'composer':
  require => Package['php5', 'curl'],
}

puphpet::ini { 'xdebug':
  value   => [
    'xdebug.default_enable = 1',
    'xdebug.remote_autostart = 0',
    'xdebug.remote_connect_back = 1',
    'xdebug.remote_enable = 1',
    'xdebug.remote_handler = "dbgp"',
    'xdebug.remote_port = 9000',
    'xdebug.var_display_max_depth = 5',
    'xdebug.var_display_max_data = 1024'
  ],
  ini     => '/etc/php5/conf.d/zzz_xdebug.ini',
  notify  => Service['apache'],
  require => Class['php'],
}

puphpet::ini { 'custom':
  value   => [
    'display_errors = On',
    'error_reporting = -1',
    "date.timezone = \"${::timezone}\""
  ],
  ini     => '/etc/php5/conf.d/zzz_custom.ini',
  notify  => Service['apache'],
  require => Class['php'],
}

class { 'mysql::server':
  config_hash   => { 'root_password' => $::pma_mysql_root_password }
}

class { 'mysql::server::account_security': }

mysql::server::config { 'extra':
  settings => {
    'mysqld' => {
      'innodb_flush_log_at_trx_commit'  => 2,
      'innodb_file_per_table'           => true,
    },
    'mysql' => {
      'no-auto-rehash'  => true,
      'show-warnings'   => true,
    }
  }
}

class { 'phpmyadmin':
  require => [Class['mysql::server'], Class['mysql::config'], Class['php']],
}

apache::vhost { 'phpmyadmin':
  server_name => "phpmyadmin.${::fqdn}",
  docroot     => '/usr/share/phpmyadmin',
  port        => 80,
  priority    => '900',
  require     => Class['phpmyadmin'],
}

if !empty($::git_config) {
  create_resources(git_config, parsejson($::git_config))
}

if !empty($::vhosts) {
  create_resources(vhost, parsejson($::vhosts))
}
