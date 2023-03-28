#!/bin/sh
# the script installs tor and its config file from files/etc/tor/torrc.
set -e
xbps-install -y tor
conffile=etc/tor/torrc
test -f /$conffile && diff /$conffile files/$conffile
if [ $? -ne 0 ]; then
    cp /$conffile /$conffile.orig
    cp files/$conffile /$conffile
    ln -sfT /etc/sv/tor /var/service/tor
    # don't touch the service if on manual control
    test ! -f /etc/sv/tor/down && sv restart tor
fi
