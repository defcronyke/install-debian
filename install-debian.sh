#!/bin/bash
# Copyright (c) 2021 Jeremy Carter <jeremy@jeremycarter.ca>
#
# Released under these license terms (MIT License):
# https://gitlab.com/defcronyke/install-debian/-/blob/master/LICENSE
#
# If you don't agree to follow these terms, you 
# aren't allowed to use this software.
#
# Install Debian
# An unofficial Debian installer. Use at your own risk.
#

install_debian() {
	echo "Installing Debian."

	WORKDIR="${WORKDIR:-"${PWD}/install-debian"}"
	TARGET_RELEASE="${TARGET_RELEASE:-"stable"}"
	DEBOOTSTRAP_VERSION="${DEBOOTSTRAP_VERSION:-$(curl -s "https://packages.debian.org/${TARGET_RELEASE}/debootstrap" | grep "debootstrap (.*)" | sed -E 's/.*\((.+)\).*/\1/')}"
	DEBOOTSTRAP_LOCATION="${DEBOOTSTRAP_LOCATION:-"https://deb.debian.org/debian/pool/main/d/debootstrap/"}"
	TARGET_MIRROR="${TARGET_MIRROR:-""}"
	TARGET_SCRIPT="${TARGET_SCRIPT:-""}"
	TARGET_ARCH="${TARGET_ARCH:-"amd64"}"
	TARGET_DIR="${TARGET_DIR:-"${WORKDIR}/debian-chroot"}"
	TARGET_PACKAGES_ARCHIVE="${TARGET_PACKAGES_ARCHIVE:-"${TARGET_DIR}.tar.gz"}"
	TARGET_PACKAGES="${TARGET_PACKAGES:-""}"
	TARGET_TASKS="${TARGET_TASKS:-"desktop xfce-desktop ssh-server laptop"}"

	# This var is used by debootstrap internally.
	# You probably shouldn't change it.
	export DEBOOTSTRAP_DIR=${DEBOOTSTRAP_DIR:-"${WORKDIR}/debootstrap"}

	echo "WORKDIR=\"$PWD\""
	echo "DEBOOTSTRAP_VERSION=\"$DEBOOTSTRAP_VERSION\""
	echo "DEBOOTSTRAP_LOCATION=\"$DEBOOTSTRAP_LOCATION\""
	echo "DEBOOTSTRAP_DIR=\"$DEBOOTSTRAP_DIR\""
	echo "TARGET_MIRROR=\"$TARGET_MIRROR\""
	echo "TARGET_SCRIPT=\"$TARGET_SCRIPT\""
	echo "TARGET_ARCH=\"$TARGET_ARCH\""
	echo "TARGET_DIR=\"$TARGET_DIR\""
	echo "TARGET_RELEASE=\"$TARGET_RELEASE\""
	echo "TARGET_PACKAGES_ARCHIVE=\"$TARGET_PACKAGES_ARCHIVE\""
	echo "TARGET_PACKAGES=\"$TARGET_PACKAGES\""
	echo "TARGET_TASKS=\"$TARGET_TASKS\""
	#echo "=\"$\""

	sudo chown "${USER}:$(id -gn)" "${PWD}"
	sudo chmod 755 "${PWD}"

	which wget >/dev/null

	if [ $? -ne 0 ]; then
		sudo apt-get update && sudo apt-get install -y wget 
	fi
	
	if [ $? -ne 0 ]; then
		sudo pacman -Sy && sudo pacman --noconfirm -S wget
	fi

	if [ $? -ne 0 ]; then
		sudo dnf update && sudo dnf install wget
	fi
	
	if [ $? -ne 0 ]; then
		echo "error: Failed installing wget. You need wget in your \$PATH for this to work. Exiting." && \
		return 254
	fi

	# Enter the $WORKDIR.
	pwd="$PWD"

	mkdir -p "$WORKDIR"

	cd "$WORKDIR"

	if [ ! -d "$DEBOOTSTRAP_DIR" ]; then
		curl -sL "$(curl -s "$DEBOOTSTRAP_LOCATION" | grep -o "\"debootstrap_${DEBOOTSTRAP_VERSION}.tar.gz\"" | tr -d '"' | sed -E "s@^(.+)\$@$DEBOOTSTRAP_LOCATION\1@" | tail -n 1)" | tar zxvf - 
	else
		echo "Already downloaded debootstrap. Skipping."
	fi

	cd "$DEBOOTSTRAP_DIR"

	if [ ! -f "$TARGET_PACKAGES_ARCHIVE" ]; then
		./debootstrap --verbose --arch="$TARGET_ARCH" --make-tarball="$TARGET_PACKAGES_ARCHIVE" "$TARGET_RELEASE" "$TARGET_DIR" $TARGET_MIRROR $TARGET_SCRIPT
	else
		echo "Already created \"$(basename $TARGET_PACKAGES_ARCHIVE)\". Skipping."
	fi

	if [ ! -d "$TARGET_DIR" ]; then
		sudo -E ./debootstrap --verbose --arch="$TARGET_ARCH" --unpack-tarball="$TARGET_PACKAGES_ARCHIVE" "$TARGET_RELEASE" "$TARGET_DIR" $TARGET_MIRROR $TARGET_SCRIPT
	else
		echo "Already created \"$(basename $TARGET_DIR)\". Skipping."
	fi

	sudo mount -t proc /proc "${TARGET_DIR}/proc/"
	sudo mount -t sysfs /sys "${TARGET_DIR}/sys/"
	sudo mount -o bind /dev "${TARGET_DIR}/dev/"

	sudo chroot "$TARGET_DIR" /bin/bash -c 'apt-get update && apt-get install locales && dpkg-reconfigure locales'

	sudo chroot "$TARGET_DIR" /bin/bash -c 'apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y'
	
	if [ ! -z "$TARGET_TASKS" ]; then
		echo "Installing tasks with tasksel: $TARGET_TASKS"
		sudo chroot "$TARGET_DIR" tasksel install "$TARGET_TASKS"
	fi

	if [ ! -z "$TARGET_PACKAGES" ]; then
		echo "Installing extra packages: $TARGET_PACKAGES"
		sudo chroot "$TARGET_DIR" apt-get install -y "$TARGET_PACKAGES"
	fi

	return_code=$?

	sudo umount "${TARGET_DIR}/proc/"
	sudo umount "${TARGET_DIR}/sys/"
	sudo umount "${TARGET_DIR}/dev/"

	cd ..

	# Return to the directory you started in.
	cd "$pwd"

	return $return_code
}

exit_install_debian() {
	if [ $1 -ne 0 ]; then
		echo "Installing Debian failed with exit code: $1"
	else
		echo "Installing Debian succeeded."
	fi

	return $1
}

cancel_install_debian() {
	echo "Debian install cancelled. Cleaning up."

	sudo umount "${TARGET_DIR}/proc/"
	sudo umount "${TARGET_DIR}/sys/"
	sudo umount "${TARGET_DIR}/dev/"

	exit_install_debian 255
	exit $?
}

trap cancel_install_debian INT

install_debian $@

exit_install_debian $?
