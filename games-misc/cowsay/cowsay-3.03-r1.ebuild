# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/games-misc/cowsay/cowsay-3.03-r1.ebuild,v 1.2 2008/01/11 16:26:57 grobian Exp $

EAPI="prefix"

inherit bash-completion eutils

DESCRIPTION="configurable talking ASCII cow (and other characters)"
HOMEPAGE="http://www.nog.net/~tony/warez/cowsay.shtml"
SRC_URI="http://www.nog.net/~tony/warez/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~ppc-aix ~x86-fbsd ~amd64-linux ~mips-linux ~x86-linux ~ppc-macos ~sparc-solaris"
IUSE=""

RDEPEND=">=dev-lang/perl-5"

src_unpack() {
	unpack ${A}
	cd "${S}"
	sed	-i \
		-e '1 c\#!'"${EPREFIX}"'/usr/bin/perl'\
		-e 's/\$version/\$VERSION/g'\
		-e "s:%PREFIX%/share/cows:${EPREFIX}/usr/share/${P}/cows:" \
		-e '/getopts/ i\$Getopt::Std::STANDARD_HELP_VERSION=1;' cowsay \
			|| die "sed cowsay failed"
	sed -i \
		-e "s|%PREFIX%/share/cows|${EPREFIX}/usr/share/${P}/cows|" cowsay.1 \
			|| die "sed cowsay.1 failed"
	epatch "${FILESDIR}/${P}"-tongue.patch
}

src_install() {
	dobin cowsay || die "dobin failed"
	doman cowsay.1
	dosym cowsay /usr/bin/cowthink
	dosym cowsay.1 /usr/share/man/man1/cowthink.1
	dodir /usr/share/${P}/cows
	cp -r cows "${ED}"/usr/share/${P}/ || die "cp failed"
	dobashcompletion "${FILESDIR}"/${PN}.bashcomp
}
