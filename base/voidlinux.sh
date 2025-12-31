#!/bin/sh
# shellcheck disable=SC2154

# base OS tweaks.
# the script assumes SYSUPDATES_CHANNEL env var is set to the desired changes
# channel, whatever the update.sh accept which is typically "dev" or "master".

# try to ensure sysupdates are running regularily before doing anoything else
xbps-install -y snooze
ln -sfT /etc/sv/snooze-hourly /var/service/snooze-hourly
mkdir -p /etc/cron.hourly
if [ ! -f /etc/cron.hourly/sysupdate ]; then
    # may have been previously installed at daily schedule
    if [ -f /etc/cron.daily/sysupdate ]; then
        mv /etc/cron.daily/sysupdate /etc/cron.hourly/
    else
        # run updates approx. every hour
        cat <<EOF > /etc/cron.hourly/sysupdate
#!/bin/sh
exec /ssd/sysupdates/update.sh "$SYSUPDATES_CHANNEL"
EOF
        chmod +x /etc/cron.hourly/sysupdate
    fi
fi

# install required packages and config files
set -e
xbps-install -y \
    cloud-guest-utils \
    curl \
    diffutils \
    gzip \
    opendoas \
    tar

# grow ssd partition and filesystem at boot (one-shot)
GROW_SSD_SVDIR=etc/sv/grow-ssd
mkdir -p /$GROW_SSD_SVDIR
mkdir -p /$GROW_SSD_SVDIR/log
if [ ! -f /$GROW_SSD_SVDIR/run ]; then
    cp "$SYSUPDATES_ROOTDIR/files/$GROW_SSD_SVDIR/run" /$GROW_SSD_SVDIR/run
    chmod +x /$GROW_SSD_SVDIR/run
fi
if [ ! -f /$GROW_SSD_SVDIR/log/run ]; then
    cp "$SYSUPDATES_ROOTDIR/files/$GROW_SSD_SVDIR/log/run" /$GROW_SSD_SVDIR/log/run
    chmod +x /$GROW_SSD_SVDIR/log/run
fi
ln -sfT /$GROW_SSD_SVDIR /var/service/grow-ssd

# openbsd's doas util config, a minial replacement of sudo
if [ ! -f /etc/doas.conf ]; then
    cat <<EOF > /etc/doas.conf
permit nopass root
permit setenv { -ENV PS1=\$DOAS_PS1 SSH_AUTH_SOCK } :wheel
EOF
fi

# automatically update xbps package database and xbps itself daily
# after xbps update, update also whole system to ensure consistency
if [ ! -f /etc/cron.daily/xbps-selfupdate ]; then
    cat <<EOF > /etc/cron.daily/xbps-selfupdate
#!/bin/sh
BACKUP_XBPS="/usr/local/bin/xbps-install.static"
if [ -z "\$XBPS_SELFUPDATE_LOCK" ]; then
    lockfile=/run/lock/xbps-selfupdate.lock
    exec env XBPS_SELFUPDATE_LOCK=1 \\
        flock --exclusive --timeout 900 "\$lockfile" "\$0"
fi
set -e
xbps-install -S
installed_ver=\$(xbps-query -p pkgver xbps 2>/dev/null)
repo_ver=\$(xbps-query -R -p pkgver xbps 2>/dev/null)
if [ "\$installed_ver" = "\$repo_ver" ]; then
    exit 0
fi
if xbps-install -uy xbps; then
    xbps-install -Suy
    exit 0
fi
if [ -x "\$BACKUP_XBPS" ]; then
    \$BACKUP_XBPS -uy xbps &&
    xbps-install -Suy
fi
EOF
    chmod +x /etc/cron.daily/xbps-selfupdate
fi
