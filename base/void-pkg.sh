#!/bin/sh
set -e

xbps-install -y opendoas tar curl diffutils

if [ ! -f /etc/doas.conf ]; then
    cat <<EOF > /etc/doas.conf
permit nopass root
permit setenv { -ENV PS1=\$DOAS_PS1 SSH_AUTH_SOCK } :wheel
EOF
fi
