#!/bin/bash

install_debian() {
	echo "Installing Debian."

	WORKDIR="${WORKDIR:-"${PWD}/install-debian"}"
	DEBOOTSTRAP_LOCATION="${DEBOOTSTRAP_LOCATION:-"https://deb.debian.org/debian/pool/main/d/debootstrap/"}"
	TARGET_MIRROR="${TARGET_MIRROR:-"http://deb.debian.org/debian/"}"
	TARGET_SCRIPT="${TARGET_SCRIPT:-""}"
	TARGET_ARCH="${TARGET_ARCH:-"amd64"}"
	TARGET_DIR="${TARGET_DIR:-"${WORKDIR}/debian-chroot"}"
	TARGET_RELEASE="${TARGET_RELEASE:-"stable"}"
	TARGET_PACKAGES_DIR=${TARGET_PACKAGES_DIR:-"${WORKDIR}/debian-packages"}
	TARGET_PACKAGES_ARCHIVE="${TARGET_PACKAGES_ARCHIVE:-"${TARGET_PACKAGES_DIR}.tar.gz"}"
	TARGET_PACKAGES="${TARGET_PACKAGES:-"xfce4 xfce4-goodies"}"

	# This var is used by debootstrap internally.
	# You probably shouldn't change it.
	export DEBOOTSTRAP_DIR=${DEBOOTSTRAP_DIR:-"${WORKDIR}/debootstrap"}

	echo "WORKDIR=\"$PWD\""
	echo "DEBOOTSTRAP_LOCATION=\"$DEBOOTSTRAP_LOCATION\""
	echo "DEBOOTSTRAP_DIR=\"$DEBOOTSTRAP_DIR\""
	echo "TARGET_MIRROR=\"$TARGET_MIRROR\""
	echo "TARGET_SCRIPT=\"$TARGET_SCRIPT\""
	echo "TARGET_ARCH=\"$TARGET_ARCH\""
	echo "TARGET_DIR=\"$TARGET_DIR\""
	echo "TARGET_RELEASE=\"$TARGET_RELEASE\""
	echo "TARGET_PACKAGES_DIR=\"$TARGET_PACKAGES_DIR\""
	echo "TARGET_PACKAGES_ARCHIVE=\"$TARGET_PACKAGES_ARCHIVE\""
	echo "TARGET_PACKAGES=\"$TARGET_PACKAGES\""
	#echo "=\"$\""

	which wget || \
	sudo apt-get update && sudo apt-get install -y wget || \
	sudo pacman -Sy && sudo pacman -S wget || \
	sudo dnf update && sudo dnf install wget || \
	echo "error: Failed installing wget. You need wget in your \$PATH for this to work. Exiting." && \
	return 254

	# Enter the $WORKDIR.
	pwd="$PWD"

	mkdir -p "$WORKDIR"

	cd "$WORKDIR"

	if [ ! -d "$DEBOOTSTRAP_DIR" ]; then
		curl -sL "$(curl -s "$DEBOOTSTRAP_LOCATION" | grep -o "\"debootstrap.*tar.gz\"" | tr -d '"' | sed -E "s@^(.+)\$@$DEBOOTSTRAP_LOCATION\1@" | tail -n 1)" | tar zxvf - 
	else
		echo "Already downloaded debootstrap. Skipping."
	fi

	cd "$DEBOOTSTRAP_DIR"

	if [ ! -f "$TARGET_PACKAGES_ARCHIVE" ]; then
		./debootstrap --keep-debootstrap-dir --arch="$TARGET_ARCH" --include="$TARGET_PACKAGES" --make-tarball="$TARGET_PACKAGES_ARCHIVE" "$TARGET_RELEASE" "$TARGET_PACKAGES_DIR" "$TARGET_MIRROR" "$TARGET_SCRIPT"
	else
		echo "Already created \"$(basename $TARGET_PACKAGES_ARCHIVE)\". Skipping."
	fi

       	sudo -E ./debootstrap --verbose --keep-debootstrap-dir --arch="$TARGET_ARCH" --unpack-tarball="$TARGET_PACKAGES_ARCHIVE" "$TARGET_RELEASE" "$TARGET_DIR" "$TARGET_MIRROR" "$TARGET_SCRIPT"

	return_code=$?

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
	exit_install_debian 255
	exit $?
}

trap cancel_install_debian INT

install_debian $@

exit_install_debian $?