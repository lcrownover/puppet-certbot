# @summary Manage certbot
#
# This class will manage certbot and allow you to automatically renew certs from an ACME endpoint.
#
# @param webserver
#   Enum of apache or nginx to configure.
#
# @param domains
#   Array of domains to register the certificate for, starting with the primary name.
#
# @param email
#   Contact email for notifications from this service.
#
# @param eab_keyid
#   ACME key ID.
#
# @param eab_hmac_key
#   ACME HMAC key.
#
# @param server
#   ACME server url. Defaults to InCommon.
#
class certbot (
  Enum['apache', 'nginx'] $webserver,
  Array[String] $domains,
  String $email,
  String $eab_keyid,
  String $eab_hmac_key,
  String $server = 'https://acme.enterprise.sectigo.com',
) {
  include stdlib

  case $facts['os']['name'] {
    default: {}
    'Ubuntu': {
      $base_packages = ['certbot']
      case $webserver {
        'apache': { $packages = $base_packages << 'python3-certbot-apache' }
        'nginx': { $packages = $base_packages << 'python3-certbot-nginx' }
        default: { $packages = $base_packages }
      }
      $systemd_service_d = '/etc/systemd/system/certbot.service.d/'
      $systemd_service_override = '/etc/systemd/system/certbot.service.d/override.conf'
      $systemd_service_name = 'certbot.timer'
    }
    'RedHat': {
      $base_packages = ['certbot']
      case $webserver {
        'apache': { $packages = $base_packages << 'certbot-apache' }
        'nginx': { $packages = $base_packages << 'certbot-nginx' }
        default: { $packages = $base_packages }
      }
      $systemd_service_d = '/etc/systemd/system/certbot-renew.service.d/'
      $systemd_service_override = '/etc/systemd/system/certbot-renew.service.d/override.conf'
      $systemd_service_name = 'certbot-renew.timer'
    }
  }
  package { $packages: }

  file { $systemd_service_d: ensure => directory }

  file { $systemd_service_override:
    content => "[Service]\nExecStart=\nExecStart=/usr/bin/certbot renew --noninteractive --${webserver} -q --force-renewal",
    notify  => Exec['systemd-daemon-reload'],
    require => File[$systemd_service_d],
  }
  exec { 'systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }
  $domain_str = join($domains, ',')
  file_line { 'certbot_domains':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => "domains = ${domain_str}",
    match   => '^domains = .*$',
    require => Package[$packages],
  }
  file_line { 'certbot_email':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => "email = ${email}",
    match   => '^email = .*$',
    require => Package[$packages],
  }
  file_line { 'certbot_server':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => "server = ${server}",
    match   => '^server = .*$',
    require => Package[$packages],
  }
  file_line { 'certbot_eab_keyid':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => "eab-kid = ${eab_keyid}",
    match   => '^eab-kid = .*$',
    require => Package[$packages],
  }
  file_line { 'certbot_eab_hmac_key':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => "eab-hmac-key = ${eab_hmac_key}",
    match   => '^eab-hmac-key = .*$',
    require => Package[$packages],
  }
  file_line { 'certbot_agree_tos':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => 'agree-tos = true',
    match   => '^agree-tos = true',
    require => Package[$packages],
  }
  file_line { 'certbot_authenticator':
    ensure  => present,
    path    => '/etc/letsencrypt/cli.ini',
    line    => "authenticator = ${webserver}",
    match   => '^authenticator = .*$',
    require => Package[$packages],
  }
  service { $systemd_service_name:
    enable    => true,
    require   => Package[$packages],
    subscribe => File[$systemd_service_override],
  }
  exec { 'request-first-cert':
    command => "/usr/bin/certbot certonly -q --${webserver} --noninteractive",
    onlyif  => 'test ! -d /etc/letsencrypt/live',
  }
}
