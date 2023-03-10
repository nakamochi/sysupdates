#!/bin/sh
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
xbps-install -y opendoas tar gzip curl diffutils

# openbsd's doas util config, a minial replacement of sudo
if [ ! -f /etc/doas.conf ]; then
    cat <<EOF > /etc/doas.conf
permit nopass root
permit setenv { -ENV PS1=\$DOAS_PS1 SSH_AUTH_SOCK } :wheel
EOF
fi
