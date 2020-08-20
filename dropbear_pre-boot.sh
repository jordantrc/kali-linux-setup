#!/bin/sh
#
# Usage: dropbear_pre-boot.sh
#
# Sets up dropbear pre-boot initramfs 
# environment for unlocking a luks-encrypted
# partition
#
# Assumes the system will use eth0 and DHCP

sudo apt update && sudo apt install -y dropbear

sudo systemctl disable dropbear
sudo systemctl stop dropbear

sudo sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear

# create SSH keys in /etc/initramfs-tools/root/.ssh
umask 077
cd /etc/initramfs-tools
sudo mkdir -p root
sudo chmod -R 700 root
sudo ssh-keygen -f root/dropbear
sudo cat root/dropbear.pub > /etc/dropbear-initramfs/authorized_keys

# network configuration
sudo sed -i "s/DEVICE=/DEVICE=\nIP=:::::eth0:dhcp/g" /etc/initramfs-tools/initramfs.conf

# setup unlock script
cat > /etc/initramfs-tools/hooks/crypt_unlock.sh << EOF2
#!/bin/sh

PREREQ="dropbear"

prereqs() {
        echo "$PREREQ"
}

case $1 in
        prereqs)
                prereqs
                exit 0
                ;;
esac

. "${CONFDIR}/initramfs.conf"
. /usr/share/initramfs-tools/hook-functions

if [ "${DROPBEAR}" != "n" ] && [ -r "/etc/crypttab" ]; then
        cat > "${DESTDIR}/bin/unlock" << EOF
#!/bin/sh
if PATH=/lib/unlock:/bin:/sbin /scripts/local-top/cryptroot; then
kill \`ps | grep cryptroot | grep -v "grep" | awk '{print \$1}'\`
# following kills the remote shell right after the passphrase is entered
kill -9 \`ps | grep "\-sh" | grep -v "grep" | awk '{print \$1}'\`
exit 0
fi
exit 1
EOF

chmod 755 "${DESTDIR}/bin/unlock"

mkdir -p "${DESTDIR}/lib/unlock"
cat > "${DESTDIR}/lib/unlock/plymouth" << EOF
#!/bin/sh
[ "\$1" == "--ping" ] && exit 1
/bin/plymouth "\$@"
EOF

chmod 755 "${DESTDIR}/lib/unlock/plymouth"

echo To unlock root partition run "unlock" >> ${DESTDIR}/etc/motd

fi
EOF2

echo "Save this private key for SSH access:"
sudo cat /etc/initramfs-tools/root/dropbear

sudo update-initramfs -u