TERMUX_PKG_HOMEPAGE=https://github.com/AndreRH/hangover
TERMUX_PKG_DESCRIPTION="A compatibility layer for running Windows programs (Hangover fork)"
TERMUX_PKG_LICENSE="LGPL-2.1"
TERMUX_PKG_LICENSE_FILE="LICENSE, LICENSE.OLD, COPYING.LIB"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="10.11"
TERMUX_PKG_REVISION=4
_REAL_VERSION="${TERMUX_PKG_VERSION/\~/-}"
TERMUX_PKG_SRCURL=(
	https://github.com/AndreRH/wine/archive/refs/tags/hangover-$_REAL_VERSION.tar.gz
	https://github.com/AndreRH/hangover/releases/download/hangover-$_REAL_VERSION/hangover_${_REAL_VERSION}_ubuntu2004_focal_arm64.tar
)
TERMUX_PKG_SHA256=(
	bbe08ba3f405e79a8d5e57472b4d0c7941e113188c05827344c37776b9d6b30a
	4f55f924c54a01c07ea3fe08ac6c4171d874d3f070ef4aac2bed5fb4458fadea
)
TERMUX_PKG_DEPENDS="fontconfig, freetype, krb5, libandroid-spawn, libc++, libgmp, libgnutls, libxcb, libxcomposite, libxcursor, libxfixes, libxrender, opengl, pulseaudio, sdl2, vulkan-loader, xorg-xrandr"
TERMUX_PKG_ANTI_BUILD_DEPENDS="vulkan-loader"
TERMUX_PKG_BUILD_DEPENDS="libandroid-spawn-static, vulkan-loader-generic"
TERMUX_PKG_NO_STATICSPLIT=true
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_TAG_TYPE="latest-release-tag"
TERMUX_PKG_EXCLUDED_ARCHES="arm, i686, x86_64"

TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_EXTRA_HOSTBUILD_CONFIGURE_ARGS="
--without-x
--disable-tests
"

# Disable userfaultfd syscall as it is missing on older Android, see #25015
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
ac_cv_header_linux_userfaultfd_h=no
enable_wineandroid_drv=no
enable_tools=yes
--prefix=$TERMUX_PREFIX/opt/hangover-wine
--exec-prefix=$TERMUX_PREFIX/opt/hangover-wine
--libdir=$TERMUX_PREFIX/opt/hangover-wine/lib
--with-wine-tools=$TERMUX_PKG_HOSTBUILD_DIR
--enable-nls
--disable-tests
--without-alsa
--without-capi
--without-coreaudio
--without-cups
--without-dbus
--without-ffmpeg
--with-fontconfig
--with-freetype
--without-gettext
--with-gettextpo=no
--without-gphoto
--with-gnutls
--without-gstreamer
--without-inotify
--with-krb5
--with-mingw=clang
--without-netapi
--without-opencl
--with-opengl
--without-osmesa
--without-oss
--without-pcap
--without-pcsclite
--with-pthread
--with-pulse
--without-sane
--with-sdl
--without-udev
--without-unwind
--without-usb
--without-v4l2
--with-vulkan
--with-xcomposite
--with-xcursor
--with-xfixes
--without-xinerama
--with-xinput
--with-xinput2
--with-xrandr
--with-xrender
--without-xshape
--without-xshm
--without-xxf86vm
--enable-archs=i386,aarch64,arm64ec
"
# TODO: `--enable-archs=arm` doesn't build with option `--with-mingw=clang`, but
# TODO: `arm64ec` doesn't build with option `--with-mingw` (arm64ec-w64-mingw32-clang)

termux_pkg_auto_update() {
	local latest_tag
	latest_tag="$(termux_github_api_get_tag "${TERMUX_PKG_SRCURL[1]}" "${TERMUX_PKG_UPDATE_TAG_TYPE}")"
	(( ${#latest_tag} )) || {
		printf '%s\n' \
		'WARN: Auto update failure!' \
		"latest_tag=${latest_tag}"
	return
	} >&2

	latest_tag="${latest_tag#*-}"
	if [[ "${latest_tag}" == "${_REAL_VERSION}" ]]; then
		echo "INFO: No update needed. Already at version '${_REAL_VERSION}'."
		return
	fi

	if [ "${latest_tag/-/\~}" != "${latest_tag}" ]; then
		latest_tag="${latest_tag/-/\~}"
	fi

	termux_pkg_upgrade_version "${latest_tag}"
}

_setup_llvm_mingw_toolchain() {
	# LLVM-mingw's version number must not be the same as the NDK's.
	local _llvm_mingw_version=21
	local _version="20250319"
	local _url="https://github.com/mstorsjo/llvm-mingw/releases/download/$_version/llvm-mingw-$_version-ucrt-ubuntu-20.04-x86_64.tar.xz"
	local _path="$TERMUX_PKG_CACHEDIR/$(basename $_url)"
	local _sha256sum=ab2a1489416fa82b3e85e88cb877053ee8a591993408caf076737d8de5ae72ca
	termux_download $_url $_path $_sha256sum
	local _extract_path="$TERMUX_PKG_CACHEDIR/llvm-mingw-toolchain-$_llvm_mingw_version"
	if [ ! -d "$_extract_path" ]; then
		mkdir -p "$_extract_path"-tmp
		tar -C "$_extract_path"-tmp --strip-component=1 -xf "$_path"
		mv "$_extract_path"-tmp "$_extract_path"
	fi
	export PATH="$_extract_path/bin:$PATH"
}

termux_step_host_build() {
	# Setup llvm-mingw toolchain
	_setup_llvm_mingw_toolchain

	# Make host wine-tools
	"$TERMUX_PKG_SRCDIR/configure" ${TERMUX_PKG_EXTRA_HOSTBUILD_CONFIGURE_ARGS}
	make -j "$TERMUX_PKG_MAKE_PROCESSES" __tooldeps__ nls/all
}

termux_step_pre_configure() {
	# Setup llvm-mingw toolchain
	_setup_llvm_mingw_toolchain

	# Fix overoptimization
	CPPFLAGS="${CPPFLAGS/-Oz/}"
	CFLAGS="${CFLAGS/-Oz/}"
	CXXFLAGS="${CXXFLAGS/-Oz/}"

	# Disable hardening
	CPPFLAGS="${CPPFLAGS/-fstack-protector-strong/}"
	CFLAGS="${CFLAGS/-fstack-protector-strong/}"
	CXXFLAGS="${CXXFLAGS/-fstack-protector-strong/}"
	LDFLAGS="${LDFLAGS/-Wl,-z,relro,-z,now/}"

	LDFLAGS+=" -landroid-spawn"
}

termux_step_make() {
	make -j $TERMUX_PKG_MAKE_PROCESSES
}

termux_step_make_install() {
	make -j $TERMUX_PKG_MAKE_PROCESSES install

	# Create hangover-wine script
	mkdir -p $TERMUX_PREFIX/bin
	cat << EOF > $TERMUX_PREFIX/bin/hangover-wine
#!$TERMUX_PREFIX/bin/env sh
exec $TERMUX_PREFIX/opt/hangover-wine/bin/wine "\$@"
EOF
	chmod +x $TERMUX_PREFIX/bin/hangover-wine
}

termux_step_post_make_install() {
	# Install FEX-based dlls
	local _type
	for _type in wowbox64 libwow64fex libarm64ecfex; do
		mkdir -p $_type
		cd $_type
		ar -x "$TERMUX_PKG_SRCDIR"/hangover-${_type}_${_REAL_VERSION}_arm64.deb
		tar xf data.tar.xz
		install -Dm644 usr/lib/wine/aarch64-windows/$_type.dll \
			"$TERMUX_PREFIX"/opt/hangover-wine/lib/wine/aarch64-windows/$_type.dll
		install -Dm644 usr/share/doc/hangover-$_type/copyright \
			"$TERMUX_PREFIX"/share/doc/hangover-$_type/copyright
		cd -
	done

	# Install LICENSE file for hangover
	mkdir -p "$TERMUX_PREFIX"/share/doc/hangover
	rm -f "$TERMUX_PREFIX"/share/doc/hangover/copyright
	curl -L https://raw.githubusercontent.com/AndreRH/hangover/refs/tags/hangover-${_REAL_VERSION}/LICENSE \
		-o "$TERMUX_PREFIX"/share/doc/hangover/copyright
}
