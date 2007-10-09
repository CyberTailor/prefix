# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-python/configobj/configobj-4.4.0-r1.ebuild,v 1.2 2007/07/05 20:15:12 pythonhead Exp $

EAPI="prefix"

NEED_PYTHON=2.3

inherit distutils

KEYWORDS="~amd64 ~x86 ~x86-macos"

DESCRIPTION="Simple but powerful config file reader and writer: an ini file round tripper."
HOMEPAGE="http://www.voidspace.org.uk/python/configobj.html"
SRC_URI="mirror://sourceforge/${PN}/${P}.zip"
LICENSE="BSD"
SLOT="0"
IUSE="doc"

DEPEND="dev-python/setuptools
	app-arch/unzip"
RDEPEND=""

src_unpack() {
	unpack ${A}
	cd ${S}
	sed -i -e 's/distutils.core/setuptools/' setup.py || die 'sed failed'
}

src_test() {
	sed -i \
		-e 's/ \(doctest\.testmod(.*\)/ sys.exit(\1[0] != 0)/' \
		configobj_test.py
	${python} configobj_test.py -v || die "configobj_test.py failed"
}

src_install() {
	DOCS="CONFIGOBJ_CHANGELOG_TODO.txt docs/configobj.txt docs/validate.txt"
	distutils_src_install

	if use doc ; then
		dohtml -r docs/*
	fi
}
