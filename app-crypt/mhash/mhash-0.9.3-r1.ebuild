# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-crypt/mhash/mhash-0.9.3-r1.ebuild,v 1.7 2007/03/18 19:50:12 grobian Exp $

EAPI="prefix"

inherit eutils

DESCRIPTION="library providing a uniform interface to a large number of hash algorithms"
HOMEPAGE="http://mhash.sourceforge.net/"
SRC_URI="mirror://sourceforge/mhash/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~ia64 ~ppc-macos ~x86"
IUSE=""

DEPEND=""
RDEPEND=""

src_unpack() {
	unpack ${A} && cd "${S}"
	# for 0.9.3 only, please send patch upstream
	epatch "${FILESDIR}/${P}-mhash_free.patch"
}

src_compile() {
	econf \
		--enable-static \
		--enable-shared || die
	emake || die "make failure"
}

src_install() {
	dodir /usr/{bin,include,lib}
	emake install DESTDIR="${D}" || die "install failure"

	dodoc AUTHORS INSTALL NEWS README TODO THANKS ChangeLog
	dodoc doc/*.txt doc/skid*
	cd doc && make mhash.html && dohtml mhash.html || die "dohtml failed"
}
