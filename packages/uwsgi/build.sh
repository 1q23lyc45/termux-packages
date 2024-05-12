TERMUX_PKG_HOMEPAGE=https://projects.unbit.it/uwsgi
TERMUX_PKG_DESCRIPTION="uWSGI application server container"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="2.0.25.1"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://github.com/unbit/uwsgi/archive/${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=a1e4a401f71d29e49d4762223412c32a42594c415f9d72d0f759680e5b8f4cf9
TERMUX_PKG_DEPENDS="libandroid-glob, libandroid-sysv-semaphore, libandroid-utimes, libcap, libcrypt, libjansson, libuuid, libxml2, openssl, pcre, python"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag"

termux_step_pre_configure() {
	export UWSGI_PYTHON_NOLIB=true
	export UWSGI_INCLUDES="$TERMUX_PREFIX/include"
	export APPEND_CFLAGS="$CPPFLAGS
		-I$TERMUX_PREFIX/include/python${TERMUX_PYTHON_VERSION}
		-DOBSOLETE_LINUX_KERNEL
		"
	LDFLAGS+="
		-lpython${TERMUX_PYTHON_VERSION}
		-landroid-glob
		-landroid-sysv-semaphore
		-landroid-utimes
		"
}

termux_step_make_install() {
	install -Dm700 -t $TERMUX_PREFIX/bin "$TERMUX_PKG_BUILDDIR/uwsgi"
}
