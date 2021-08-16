If your zonemaster version is smaller than v6.2.1, and not upgraded, use the
instructions in this file.

## New dependencies

### FreeBSD

```sh
pkg install p5-Plack-Middleware-ReverseProxy
```

### Debian / Ubuntu

```sh
sudo apt-get install libplack-middleware-reverseproxy-perl
```

### Centos

```sh
sudo cpanm Plack::Middleware::ReverseProxy
```
