#!/usr/bin/env bash
#
# One-time setup of the PS4 toolchain on Ubuntu (tested on 26.04, also WSL2).
# Installs host build tools, pacman, the PacBrew repository and the OpenOrbis
# toolchain + portlibs into /opt/pacbrew/ps4/openorbis. Needs root.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "run as root (sudo $0)" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
	pacman-package-manager makepkg libarchive-tools \
	build-essential autoconf automake libtool cmake ninja-build nasm \
	git curl python3 pkg-config zip unzip

if ! grep -q '^\[pacbrew\]' /etc/pacman.conf; then
	cat >> /etc/pacman.conf <<-'EOF'

		[pacbrew]
		SigLevel = Optional TrustAll
		Server = https://pacman.mydedibox.fr/pacbrew/packages/
	EOF
fi

pacman -Sy --noconfirm
pacman -S --noconfirm --needed ps4-openorbis ps4-openorbis-portlibs

echo
echo "Toolchain installed in /opt/pacbrew/ps4/openorbis."
echo "Now build with: platform/ps4/build.sh"
