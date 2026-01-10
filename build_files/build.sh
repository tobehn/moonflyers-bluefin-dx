#!/bin/bash
set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

### Basis-Pakete

dnf5 install -y tmux
dnf5 install -y logiops
dnf5 install -y spacenavd
rpm-ostree install screen

# Exec perms for symlink script
chmod +x /usr/bin/fixtuxedo
systemctl enable /etc/systemd/system/fixtuxedo.service

### LogiOps-Override nur, wenn USERNAME gesetzt ist

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

### Tuxedo-Treiber bauen (als nicht-root User) und installieren

### Kernel-Header für kmod-Build installieren
dnf5 install -y kernel-devel

# Kernel-Version aus installiertem kernel-devel ermitteln (nicht uname -r, das ist der Host-Kernel)
KVER=$(rpm -q kernel-devel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -1)
echo "Building for kernel: $KVER"

# Symlink für Kernel-Build-Verzeichnis erstellen (fehlt in OSTree-Container-Builds)
mkdir -p "/lib/modules/$KVER"
ln -sf "/usr/src/kernels/$KVER" "/lib/modules/$KVER/build"
echo "Created symlink: /lib/modules/$KVER/build -> /usr/src/kernels/$KVER"
ls -la "/lib/modules/$KVER/"

# uname-Wrapper erstellen, damit "uname -r" die richtige Kernel-Version zurückgibt
# (rpmbuild/make verwendet uname -r intern, aber das gibt den Host-Kernel zurück)
mv /usr/bin/uname /usr/bin/uname.real
cat > /usr/bin/uname << UNAME_WRAPPER
#!/bin/bash
if [[ "\$*" == *"-r"* ]] || [[ "\$*" == *"--kernel-release"* ]]; then
  echo "$KVER"
else
  /usr/bin/uname.real "\$@"
fi
UNAME_WRAPPER
chmod +x /usr/bin/uname
echo "Created uname wrapper: uname -r now returns $KVER"

rpm-ostree install rpm-build rpmdevtools kmodtool

BUILD_USER="builder"
BUILD_HOME="/var/home/${BUILD_USER}"

if ! id -u "$BUILD_USER" >/dev/null 2>&1; then
  useradd -m -d "$BUILD_HOME" -s /bin/bash "$BUILD_USER"
fi

mkdir -p "$BUILD_HOME"
chown -R "$BUILD_USER":"$BUILD_USER" "$BUILD_HOME"

# /tmp muss world-writable sein für rpmbuild (check-buildroot verwendet mktemp)
chmod 1777 /tmp

su - "$BUILD_USER" -c "
set -euo pipefail

rpmdev-setuptree
cd \"\$HOME\"

rm -rf tuxedo-drivers-kmod
git clone https://github.com/tobehn/tuxedo-drivers-kmod
cd tuxedo-drivers-kmod

echo '=== Build RPMs for kernel: $KVER ==='
./build.sh \"$KVER\"

echo '=== Built RPMs ==='
find \"\$HOME/rpmbuild/RPMS\" -type f
"

# Nur Nicht-akmod-RPMs installieren
rpm_files=()
shopt -s nullglob
for rpm in "${BUILD_HOME}/rpmbuild/RPMS/x86_64/"*.rpm; do
  case "$(basename "$rpm")" in
    akmod-*|*akmod-*)
      echo "Skipping akmod package $rpm"
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

### Tuxedo Control Center „/opt“-Workaround

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

systemctl enable podman.socket
