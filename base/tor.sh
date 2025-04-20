#!/bin/sh
# shellcheck disable=SC2015

# the script installs tor and its config file from files/etc/tor/torrc.
xbps-install -y tor
conffile=etc/tor/torrc
test -f /$conffile && diff /$conffile files/$conffile || {
    cp /$conffile /$conffile.orig
    cp files/$conffile /$conffile
    ln -sfT /etc/sv/tor /var/service/tor
    # don't touch the service if on manual control
    test ! -f /etc/sv/tor/down && sv restart tor
}
