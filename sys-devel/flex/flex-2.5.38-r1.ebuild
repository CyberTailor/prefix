# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/flex/flex-2.5.38-r1.ebuild,v 1.2 2014/03/28 15:37:24 ottxor Exp $

EAPI="4"

inherit flag-o-matic

DESCRIPTION="The Fast Lexical Analyzer"
HOMEPAGE="http://flex.sourceforge.net/"
SRC_URI="mirror://sourceforge/flex/${P}.tar.xz"

LICENSE="FLEX"
SLOT="0"
KEYWORDS="~ppc-aix ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="nls static test"

# We want bison explicitly and not yacc in general #381273
RDEPEND="sys-devel/m4"
DEPEND="${RDEPEND}
	app-arch/xz-utils
	nls? ( sys-devel/gettext )
	test? ( sys-devel/bison )"

src_configure() {
	use static && append-ldflags -static
	# Do not install shared libs #503522
	econf \
		--disable-shared \
		$(use_enable nls) \
		--docdir='$(datarootdir)/doc/'${PF}
}

src_install() {
	default
	dodoc ONEWS
	find "${ED}" -name '*.la' -delete
	rm "${ED}"/usr/share/doc/${PF}/{COPYING,flex.pdf} || die
	dosym flex /usr/bin/lex
}
