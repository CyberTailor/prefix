# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"
WANT_LIBTOOL="none"

inherit autotools check-reqs flag-o-matic multiprocessing pax-utils
inherit prefix python-utils-r1 toolchain-funcs verify-sig

MY_PV=${PV/_rc/rc}
MY_P="Python-${MY_PV%_p*}"
PYVER=$(ver_cut 1-2)
PATCHSET="python-gentoo-patches-${MY_PV}"
PREFIX_PATCHSET="python-prefix-gentoo-${MY_PV}-patches-r3"

DESCRIPTION="An interpreted, interactive, object-oriented programming language"
HOMEPAGE="
	https://www.python.org/
	https://github.com/python/cpython/
"
SRC_URI="
	https://www.python.org/ftp/python/${PV%%_*}/${MY_P}.tar.xz
	https://dev.gentoo.org/~mgorny/dist/python/${PATCHSET}.tar.xz
	https://dev.gentoo.org/~grobian/distfiles/${PREFIX_PATCHSET}.tar.xz
	verify-sig? (
		https://www.python.org/ftp/python/${PV%%_*}/${MY_P}.tar.xz.asc
	)
"
S="${WORKDIR}/${MY_P}"

LICENSE="PSF-2"
SLOT="${PYVER}"
KEYWORDS="~amd64-linux ~x86-linux ~arm64-macos ~ppc-macos ~x64-macos ~x64-solaris"
IUSE="
	aqua
	bluetooth build +ensurepip examples gdbm hardened libedit lto
	+ncurses pgo +readline +sqlite +ssl test tk valgrind
"
RESTRICT="!test? ( test )"

# Do not add a dependency on dev-lang/python to this ebuild.
# If you need to apply a patch which requires python for bootstrapping, please
# run the bootstrap code on your dev box and include the results in the
# patchset. See bug 447752.

RDEPEND="
	app-arch/bzip2:=
	app-arch/xz-utils:=
	app-crypt/libb2
	>=dev-libs/expat-2.1:=
	dev-libs/libffi:=
	dev-python/gentoo-common
	kernel_linux? ( sys-apps/util-linux:= )
	>=sys-libs/zlib-1.1.3:=
	virtual/libcrypt:=
	virtual/libintl
	ensurepip? ( dev-python/ensurepip-wheels )
	gdbm? ( sys-libs/gdbm:=[berkdb] )
	ncurses? ( >=sys-libs/ncurses-5.2:= )
	readline? (
		!libedit? ( >=sys-libs/readline-4.1:= )
		libedit? ( dev-libs/libedit:= )
	)
	sqlite? ( >=dev-db/sqlite-3.3.8:3= )
	ssl? ( >=dev-libs/openssl-1.1.1:= )
	tk? (
		>=dev-lang/tcl-8.0:=
		>=dev-lang/tk-8.0:=
		dev-tcltk/blt:=
		dev-tcltk/tix
	)
	!!<sys-apps/sandbox-2.21
	elibc_Darwin? ( sys-libs/native-uuid )
	elibc_SunOS? ( sys-libs/libuuid )
"
# bluetooth requires headers from bluez
DEPEND="
	${RDEPEND}
	bluetooth? ( net-wireless/bluez )
	test? ( app-arch/xz-utils[extra-filters(+)] )
	valgrind? ( dev-util/valgrind )
"
# autoconf-archive needed to eautoreconf
BDEPEND="
	dev-build/autoconf-archive
	app-alternatives/awk
	virtual/pkgconfig
	verify-sig? ( sec-keys/openpgp-keys-python )
"
RDEPEND+="
	!build? ( app-misc/mime-types )
"
if [[ ${PV} != *_alpha* ]]; then
	RDEPEND+="
		dev-lang/python-exec[python_targets_python${PYVER/./_}(-)]
	"
fi

VERIFY_SIG_OPENPGP_KEY_PATH=${BROOT}/usr/share/openpgp-keys/python.org.asc

# large file tests involve a 2.5G file being copied (duplicated)
CHECKREQS_DISK_BUILD=5500M

QA_PKGCONFIG_VERSION=${PYVER}
# false positives -- functions specific to *BSD
QA_CONFIG_IMPL_DECL_SKIP=( chflags lchflags )

pkg_pretend() {
	use test && check-reqs_pkg_pretend
}

pkg_setup() {
	use test && check-reqs_pkg_setup
}

src_unpack() {
	if use verify-sig; then
		verify-sig_verify_detached "${DISTDIR}"/${MY_P}.tar.xz{,.asc}
	fi
	default
}

src_prepare() {
	# Ensure that internal copies of expat and libffi are not used.
	rm -r Modules/expat || die
	rm -r Modules/_ctypes/libffi* || die

	local PATCHES=(
		"${WORKDIR}/${PATCHSET}"
		# Prefix' round of patches
		"${WORKDIR}"/${PREFIX_PATCHSET}
	)

	default

	# https://bugs.gentoo.org/850151
	sed -i -e "s:@@GENTOO_LIBDIR@@:$(get_libdir):g" setup.py || die

	# force the correct number of jobs
	# https://bugs.gentoo.org/737660
	local jobs=$(makeopts_jobs)
	sed -i -e "s:-j0:-j${jobs}:" Makefile.pre.in || die
	sed -i -e "/self\.parallel/s:True:${jobs}:" setup.py || die

	# workaround a problem on ppc-macos with >=GCC-8 where dtoa gets
	# miscompiled when optimisation is being used
	if [[ ${CHOST} == powerpc*-darwin* ]] && \
		tc-is-gcc && [[ $(gcc-major-version) -ge 8 ]] ;
	then
		sed -i \
			-e '/^CFLAGS_ALIASING=/s/$/ -fno-tree-ter/' Makefile.pre.in || die
	fi

	# Darwin 9's kqueue seems to act up (at least at this stage), so
	# make Python's selectors resort to poll() or select()
	if [[ ${CHOST} == powerpc*-darwin9 ]] ; then
		sed -i \
			-e 's/KQUEUE/KQUEUE_DISABLED/' \
			configure.ac configure || die
	fi

	if [[ ${CHOST} == *-darwin19 ]] ; then
		# HAVE_DYLD_SHARED_CACHE_CONTAINS_PATH is set because
		# _dyld_shared_cache_contains_path could be found, yet it cannot
		# be resolved when dlopen()ing, so simply pretend it doesn't
		# exist here
		sed -i \
			-e 's/_dyld_shared_cache_contains_path/disabled&/' \
			configure.ac configure || die
	fi

	if [[ ${CHOST} == *-solaris* ]] ; then
		# OpenIndiana/Solaris 11 defines inet_aton no longer in
		# libresolv, so use hstrerror to check if we need -lresolv
		sed -i -e '/AC_CHECK_LIB/s/inet_aton/hstrerror/' \
			configure.ac configure || die
	fi

	eautoreconf
}

src_configure() {
	local disable
	# disable automagic bluetooth headers detection
	if ! use bluetooth; then
		local -x ac_cv_header_bluetooth_bluetooth_h=no
	fi

	append-flags -fwrapv
	filter-flags -malign-double

	# https://bugs.gentoo.org/700012
	if is-flagq -flto || is-flagq '-flto=*'; then
		append-cflags $(test-flags-CC -ffat-lto-objects)
	fi

	# Export CXX so it ends up in /usr/lib/python3.X/config/Makefile.
	# PKG_CONFIG needed for cross.
	tc-export CXX PKG_CONFIG

	local dbmliborder=
	if use gdbm; then
		dbmliborder+="${dbmliborder:+:}gdbm"
	fi

	if use pgo; then
		local profile_task_flags=(
			-m test
			"-j$(makeopts_jobs)"
			--pgo-extended
			-u-network

			# We use a timeout because of how often we've had hang issues
			# here. It also matches the default upstream PROFILE_TASK.
			--timeout 1200

			-x test_gdb

			# All of these seem to occasionally hang for PGO inconsistently
			# They'll even hang here but be fine in src_test sometimes.
			# bug #828535 (and related: bug #788022)
			-x test_asyncio
			-x test_httpservers
			-x test_logging
			-x test_multiprocessing_fork
			-x test_socket
			-x test_xmlrpc

			# Hangs (actually runs indefinitely executing itself w/ many cpython builds)
			# bug #900429
			-x test_tools
		)

		if has_version "app-arch/rpm" ; then
			# Avoid sandbox failure (attempts to write to /var/lib/rpm)
			profile_task_flags+=(
				-x test_distutils
			)
		fi
		local -x PROFILE_TASK="${profile_task_flags[*]}"
	fi

	# flock on 32-bits sparc Solaris is broken
	[[ ${CHOST} == sparc-*-solaris* ]] && \
		export ac_cv_flock_decl=no

	local myeconfargs=(
		# glibc-2.30 removes it; since we can't cleanly force-rebuild
		# Python on glibc upgrade, remove it proactively to give
		# a chance for users rebuilding python before glibc
		# except on non-glibc systems this breaks the build, so be
		# conservative!
		$(use elibc_glibc && echo ac_cv_header_stropts_h=no)

		$(use aqua && echo --config-cache)
		--enable-shared
		--without-static-libpython
		--enable-ipv6
		--infodir='${prefix}/share/info'
		--mandir='${prefix}/share/man'
		--with-computed-gotos
		--with-dbmliborder="${dbmliborder}"
		--with-libc=
		--enable-loadable-sqlite-extensions
		--without-ensurepip
		--with-system-expat
		--with-system-ffi
		--with-platlibdir=lib
		--with-pkg-config=yes
		--with-wheel-pkg-dir="${EPREFIX}"/usr/lib/python/ensurepip

		$(use_with lto)
		$(use_enable pgo optimizations)
		$(use_with readline readline "$(usex libedit editline readline)")
		$(use_with valgrind)
	)

	# disable implicit optimization/debugging flags
	local -x OPT=

	if tc-is-cross-compiler ; then
		# Hack to workaround get_libdir not being able to handle CBUILD, bug #794181
		local cbuild_libdir=$(unset PKG_CONFIG_PATH ; $(tc-getBUILD_PKG_CONFIG) --keep-system-libs --libs-only-L libffi)

		# pass system CFLAGS & LDFLAGS as _NODIST, otherwise they'll get
		# propagated to sysconfig for built extensions
		local -x CFLAGS_NODIST=${CFLAGS_FOR_BUILD}
		local -x LDFLAGS_NODIST=${LDFLAGS_FOR_BUILD}
		local -x CFLAGS= LDFLAGS=

		# We need to build our own Python on CBUILD first, and feed it in.
		# bug #847910
		local myeconfargs_cbuild=(
			"${myeconfargs[@]}"

			--libdir="${cbuild_libdir:2}"

			# Avoid needing to load the right libpython.so.
			--disable-shared

			# As minimal as possible for the mini CBUILD Python
			# we build just for cross to satisfy --with-build-python.
			--without-lto
			--without-readline
			--disable-optimizations
		)

		myeconfargs+=(
			# Point the imminent CHOST build to the Python we just
			# built for CBUILD.
			--with-build-python="${WORKDIR}"/${P}-${CBUILD}/python
		)

		mkdir "${WORKDIR}"/${P}-${CBUILD} || die
		pushd "${WORKDIR}"/${P}-${CBUILD} &> /dev/null || die
		# We disable _ctypes and _crypt for CBUILD because Python's setup.py can't handle locating
		# libdir correctly for cross.
		PYTHON_DISABLE_MODULES="${PYTHON_DISABLE_MODULES} _ctypes _crypt" \
			ECONF_SOURCE="${S}" econf_build "${myeconfargs_cbuild[@]}"

		# Avoid as many dependencies as possible for the cross build.
		cat >> Makefile <<-EOF || die
			MODULE_NIS_STATE=disabled
			MODULE__DBM_STATE=disabled
			MODULE__GDBM_STATE=disabled
			MODULE__DBM_STATE=disabled
			MODULE__SQLITE3_STATE=disabled
			MODULE__HASHLIB_STATE=disabled
			MODULE__SSL_STATE=disabled
			MODULE__CURSES_STATE=disabled
			MODULE__CURSES_PANEL_STATE=disabled
			MODULE_READLINE_STATE=disabled
			MODULE__TKINTER_STATE=disabled
			MODULE_PYEXPAT_STATE=disabled
			MODULE_ZLIB_STATE=disabled
		EOF

		# Unfortunately, we do have to build this immediately, and
		# not in src_compile, because CHOST configure for Python
		# will check the existence of the --with-build-python value
		# immediately.
		PYTHON_DISABLE_MODULES="${PYTHON_DISABLE_MODULES} _ctypes _crypt" emake
		popd &> /dev/null || die
	fi

	# pass system CFLAGS & LDFLAGS as _NODIST, otherwise they'll get
	# propagated to sysconfig for built extensions
	local -x CFLAGS_NODIST=${CFLAGS}
	local -x LDFLAGS_NODIST=${LDFLAGS}
	local -x CFLAGS= LDFLAGS=

	# Fix implicit declarations on cross and prefix builds. Bug #674070.
	if use ncurses; then
		append-cppflags -I"${ESYSROOT}"/usr/include/ncursesw
	fi

	if use aqua ; then
		ECONF_SOURCE="${S}" OPT="" \
			econf \
			--enable-framework="${EPREFIX}" \
			--config-cache
	fi

	hprefixify setup.py
	econf "${myeconfargs[@]}"

	if grep -q "#define POSIX_SEMAPHORES_NOT_ENABLED 1" pyconfig.h; then
		eerror "configure has detected that the sem_open function is broken."
		eerror "Please ensure that /dev/shm is mounted as a tmpfs with mode 1777."
		die "Broken sem_open function (bug 496328)"
	fi

	# force-disable modules we don't want built
	local disable_modules=( NIS )
	use gdbm || disable_modules+=( _GDBM _DBM )
	use sqlite || disable_modules+=( _SQLITE3 )
	use ssl || disable_modules+=( _HASHLIB _SSL )
	use ncurses || disable_modules+=( _CURSES _CURSES_PANEL )
	use readline || disable_modules+=( READLINE )
	use tk || disable_modules+=( _TKINTER )
	use kernel_linux || disable_modules+=( OSSAUDIODEV )
	[[ ${CHOST} == *-apple-darwin* ]] && disable_modules+=( _SCPROXY )

	local mod
	for mod in "${disable_modules[@]}"; do
		echo "MODULE_${mod}_STATE=disabled"
	done >> Makefile || die

	# install epython.py as part of stdlib
	echo "EPYTHON='python${PYVER}'" > Lib/epython.py || die
}

src_compile() {
	# Ensure sed works as expected
	# https://bugs.gentoo.org/594768
	local -x LC_ALL=C
	# Prevent using distutils bundled by setuptools.
	# https://bugs.gentoo.org/823728
	export SETUPTOOLS_USE_DISTUTILS=stdlib
	export PYTHONSTRICTEXTENSIONBUILD=1

	# Save PYTHONDONTWRITEBYTECODE so that 'has_version' doesn't
	# end up writing bytecode & violating sandbox.
	# bug #831897
	local -x _PYTHONDONTWRITEBYTECODE=${PYTHONDONTWRITEBYTECODE}

	if use pgo ; then
		# bug 660358
		local -x COLUMNS=80
		local -x PYTHONDONTWRITEBYTECODE=

		addpredict "/usr/lib/python${PYVER}/site-packages"
	fi

	# also need to clear the flags explicitly here or they end up
	# in _sysconfigdata*
	emake CPPFLAGS= CFLAGS= LDFLAGS=

	# Restore saved value from above.
	local -x PYTHONDONTWRITEBYTECODE=${_PYTHONDONTWRITEBYTECODE}

	# Work around bug 329499. See also bug 413751 and 457194.
	if has_version dev-libs/libffi[pax-kernel]; then
		pax-mark E python
	else
		pax-mark m python
	fi
}

src_test() {
	# Tests will not work when cross compiling.
	if tc-is-cross-compiler; then
		elog "Disabling tests due to crosscompiling."
		return
	fi

	# this just happens to skip test_support.test_freeze that is broken
	# without bundled expat
	# TODO: get a proper skip for it upstream
	local -x LOGNAME=buildbot

	local test_opts=(
		-u-network
		-j "$(makeopts_jobs)"

		# fails
		-x test_gdb
	)

	if use sparc ; then
		# bug #788022
		test_opts+=(
			-x test_multiprocessing_fork
			-x test_multiprocessing_forkserver
		)
	fi

	# workaround docutils breaking tests
	cat > Lib/docutils.py <<-EOF || die
		raise ImportError("Thou shalt not import!")
	EOF

	# bug 660358
	local -x COLUMNS=80
	local -x PYTHONDONTWRITEBYTECODE=
	# workaround https://bugs.gentoo.org/775416
	addwrite "/usr/lib/python${PYVER}/site-packages"

	nonfatal emake test EXTRATESTOPTS="${test_opts[*]}" \
		CPPFLAGS= CFLAGS= LDFLAGS= < /dev/tty
	local ret=${?}

	rm Lib/docutils.py || die

	[[ ${ret} -eq 0 ]] || die "emake test failed"
}

src_install() {
	local libdir=${ED}/usr/lib/python${PYVER}

	# -j1 hack for now for bug #843458
	emake -j1 DESTDIR="${D}" altinstall

	if use aqua ; then
		# avoid config.status to be triggered
		find Mac -name "Makefile" -exec touch \{\} + || die

		# Python_Launcher is kind of a wrapper, and we should fix it for
		# Prefix (it uses /usr/bin/pythonw) so useless
		# IDLE doesn't run, no idea, but definitely not used
		emake DESTDIR="${D}" -C Mac install_Python || die
		rmdir "${ED}"/Applications/Python* || die
		rmdir "${ED}"/Applications || die

		local fwdir=/Frameworks/Python.framework/Versions/${PYVER}
		ln -s "${EPREFIX}"/usr/include/python${PYVER} \
			"${ED}${fwdir}"/Headers || die
		ln -s "${EPREFIX}"/usr/lib/libpython${PYVER}.dylib \
			"${ED}${fwdir}"/Python || die
	fi

	# Fix collisions between different slots of Python.
	rm -f "${ED}/usr/$(get_libdir)/libpython3$(get_libname)" || die

	# Cheap hack to get version with ABIFLAGS
	local abiver=$(cd "${ED}/usr/include"; echo python*)
	if [[ ${abiver} != python${PYVER} ]]; then
		# Replace python3.X with a symlink to python3.Xm
		rm "${ED}/usr/bin/python${PYVER}" || die
		dosym "${abiver}" "/usr/bin/python${PYVER}"
		# Create python3.X-config symlink
		dosym "${abiver}-config" "/usr/bin/python${PYVER}-config"
		# Create python-3.5m.pc symlink
		dosym "python-${PYVER}.pc" "/usr/$(get_libdir)/pkgconfig/${abiver/${PYVER}/-${PYVER}}.pc"
	fi

	# python seems to get rebuilt in src_install (bug 569908)
	# Work around it for now.
	if has_version dev-libs/libffi[pax-kernel]; then
		pax-mark E "${ED}/usr/bin/${abiver}"
	else
		pax-mark m "${ED}/usr/bin/${abiver}"
	fi

	rm -r "${libdir}"/ensurepip/_bundled || die
	if ! use ensurepip; then
		rm -r "${libdir}"/ensurepip || die
	fi
	if ! use sqlite; then
		rm -r "${libdir}/"sqlite3 || die
	fi
	if ! use tk; then
		rm -r "${ED}/usr/bin/idle${PYVER}" || die
		rm -r "${libdir}/"{idlelib,tkinter,test/test_tk*} || die
	fi

	ln -s ../python/EXTERNALLY-MANAGED "${libdir}/EXTERNALLY-MANAGED" || die

	dodoc Misc/{ACKS,HISTORY,NEWS}

	if use examples; then
		docinto examples
		find Tools -name __pycache__ -exec rm -fr {} + || die
		dodoc -r Tools
	fi
	insinto /usr/share/gdb/auto-load/usr/$(get_libdir) #443510
	local libname=$(
		printf 'e:\n\t@echo $(INSTSONAME)\ninclude Makefile\n' |
		emake --no-print-directory -s -f - 2>/dev/null
	)
	newins Tools/gdb/libpython.py "${libname}"-gdb.py

	newconfd "${FILESDIR}/pydoc.conf" pydoc-${PYVER}
	newinitd "${FILESDIR}/pydoc.init" pydoc-${PYVER}
	sed \
		-e "s:@PYDOC_PORT_VARIABLE@:PYDOC${PYVER/./_}_PORT:" \
		-e "s:@PYDOC@:pydoc${PYVER}:" \
		-i "${ED}/etc/conf.d/pydoc-${PYVER}" \
		"${ED}/etc/init.d/pydoc-${PYVER}" || die "sed failed"

	# python-exec wrapping support
	local pymajor=${PYVER%.*}
	local EPYTHON=python${PYVER}
	local scriptdir=${D}$(python_get_scriptdir)
	mkdir -p "${scriptdir}" || die
	# python and pythonX
	ln -s "../../../bin/${abiver}" "${scriptdir}/python${pymajor}" || die
	ln -s "python${pymajor}" "${scriptdir}/python" || die
	# python-config and pythonX-config
	# note: we need to create a wrapper rather than symlinking it due
	# to some random dirname(argv[0]) magic performed by python-config
	cat > "${scriptdir}/python${pymajor}-config" <<-EOF || die
		#!/bin/sh
		exec "${abiver}-config" "\${@}"
	EOF
	chmod +x "${scriptdir}/python${pymajor}-config" || die
	ln -s "python${pymajor}-config" "${scriptdir}/python-config" || die
	# 2to3, pydoc
	ln -s "../../../bin/2to3-${PYVER}" "${scriptdir}/2to3" || die
	ln -s "../../../bin/pydoc${PYVER}" "${scriptdir}/pydoc" || die
	# idle
	if use tk; then
		ln -s "../../../bin/idle${PYVER}" "${scriptdir}/idle" || die
	fi
}

pkg_postinst() {
	local v
	for v in ${REPLACING_VERSIONS}; do
		if ver_test "${v}" -lt 3.11.0_beta4-r2; then
			ewarn "Python 3.11.0b4 has changed its module ABI.  The .pyc files"
			ewarn "installed previously are no longer valid and will be regenerated"
			ewarn "(or ignored) on the next import.  This may cause sandbox failures"
			ewarn "when installing some packages and checksum mismatches when removing"
			ewarn "old versions.  To actively prevent this, rebuild all packages"
			ewarn "installing Python 3.11 modules, e.g. using:"
			ewarn
			ewarn "  emerge -1v /usr/lib/python3.11/site-packages"
		fi
	done
}
