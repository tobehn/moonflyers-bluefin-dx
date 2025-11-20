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
dnf5 install -y spacenavd
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


# Run the tuxedo driver build as a non-root user (akmods requires this).
BUILD_USER="${USERNAME:-builder}"
BUILD_HOME="/var/home/${BUILD_USER}"

if ! id -u "$BUILD_USER" >/dev/null 2>&1; then
    useradd -m -d "$BUILD_HOME" -s /bin/bash "$BUILD_USER"
fi

# Ensure ownership of the home dir
mkdir -p "$BUILD_HOME"
chown -R "$BUILD_USER":"$BUILD_USER" "$BUILD_HOME"

# Run rpmdev-setuptree and the upstream build as the non-root user
su - "$BUILD_USER" -c '
set -euo pipefail
rpmdev-setuptree
cd "$HOME"
git clone https://github.com/tobehn/tuxedo-drivers-kmod
cd tuxedo-drivers-kmod
./build.sh
find ~/rpmbuild/RPMS/ -type f
'

# Extract the Version value from the spec file (read from the build user's tree)
export TD_VERSION=$(grep -E "^Version:" "$BUILD_HOME/tuxedo-drivers-kmod/tuxedo-drivers-kmod-common.spec" | awk "{print \$2}")

 # Install produced RPMs but skip akmod packages because akmods' postinstall
 # tries to build as root which fails inside the container/build environment.
 rpm_files=()
 shopt -s nullglob
 for rpm in "${BUILD_HOME}/rpmbuild/RPMS/x86_64/"*.rpm; do
   case "$(basename "$rpm")" in
     akmod-*|*akmod-*)
       echo "Skipping akmod package $rpm"
       continue
       ;;
     *)
       rpm_files+=("$rpm")
       ;;
   esac
 done
 if [ ${#rpm_files[@]} -eq 0 ]; then
   echo "No RPMs to install after filtering akmod packages" >&2
   exit 1
 fi
 rpm-ostree install "${rpm_files[@]}"

# ...existing code...

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
