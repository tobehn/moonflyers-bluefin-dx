#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux
dnf5 install -y logiops
rpm-ostree install screen

#Exec perms for symlink script
chmod +x /usr/bin/fixtuxedo
#And autorun
systemctl enable /etc/systemd/system/fixtuxedo.service

#Handle the logiops installation

# ---- LogiOps Override nur, wenn USERNAME gesetzt ist ----
if [ -n "${USERNAME:-}" ]; then
  install -d -m 755 "/var/home/${USERNAME}/.config/logiops"
  : > "/var/home/${USERNAME}/.config/logiops/logid.cfg"

  install -d /usr/lib/systemd/system/logid.service.d
  cat > /usr/lib/systemd/system/logid.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/logid -c /var/${USERNAME}/.config/logiops/logid.cfg
EOF

  cat > /usr/lib/tmpfiles.d/logiops.conf <<EOF
d /var/home/${USERNAME} 0755 ${USERNAME} ${USERNAME} -
d /var/home/${USERNAME}/.config 0755 ${USERNAME} ${USERNAME} -
d /var/home/${USERNAME}/.config/logiops 0755 ${USERNAME} ${USERNAME} -
f /var/home/${USERNAME}/.config/logiops/logid.cfg 0644 ${USERNAME} ${USERNAME} -
EOF

  systemctl enable logid.service
else
  echo "NOTE: Skip LogiOps override (USERNAME not set; PR ohne Secrets?)."
fi


#Build and install tuxedo drivers
rpm-ostree install rpm-build
rpm-ostree install rpmdevtools
rpm-ostree install kmodtool

export HOME=/tmp

cd /tmp

rpmdev-setuptree

git clone https://github.com/tobehn/tuxedo-drivers-kmod

cd tuxedo-drivers-kmod/
./build.sh
find ~/rpmbuild/RPMS/ -type f
cd ..

# Extract the Version value from the spec file
export TD_VERSION=$(cat tuxedo-drivers-kmod/tuxedo-drivers-kmod-common.spec | grep -E '^Version:' | awk '{print $2}')


#rpm-ostree install ~/rpmbuild/RPMS/x86_64/akmod-tuxedo-drivers-$TD_VERSION-1.fc41.x86_64.rpm ~/rpmbuild/RPMS/x86_64/tuxedo-drivers-kmod-$TD_VERSION-1.fc41.x86_64.rpm ~/rpmbuild/RPMS/x86_64/tuxedo-drivers-kmod-common-$TD_VERSION-1.fc41.x86_64.rpm ~/rpmbuild/RPMS/x86_64/kmod-tuxedo-drivers-$TD_VERSION-1.fc41.x86_64.rpm

rpm-ostree install ~/rpmbuild/RPMS/x86_64/*.rpm

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

akmods --force --kernels "${KERNEL_VERSION}" --kmod "tuxedo-drivers-kmod"

#Hacky workaround to make TCC install elsewhere
mkdir -p /usr/share
rm /opt
ln -s /usr/share /opt

rpm-ostree install tuxedo-control-center

cd /
rm /opt
ln -s var/opt /opt
ls -al /

rm /usr/bin/tuxedo-control-center
ln -s /usr/share/tuxedo-control-center/tuxedo-control-center /usr/bin/tuxedo-control-center

sed -i 's|/opt|/usr/share|g' /etc/systemd/system/tccd.service
sed -i 's|/opt|/usr/share|g' /usr/share/applications/tuxedo-control-center.desktop

systemctl enable tccd.service

systemctl enable tccd-sleep.service

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

# this would install a package from rpmfusion
# rpm-ostree install vlc

#### Example for enabling a System Unit File
systemctl enable podman.socket
