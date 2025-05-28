# certbot

This module manages `certbot` on RHEL and Ubuntu systems.

## Examples

Typical setup:

```puppet
class { 'certbot':
  domains      => ['mydomain.example.org'],
  webserver    => 'apache', # or nginx
  email        => 'me@example.org',
  eab_keyid    => 'KEY ID',
  eab_hmac_key => 'HMAC KEY',
}
```
