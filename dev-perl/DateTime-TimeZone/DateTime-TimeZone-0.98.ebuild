# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-perl/DateTime-TimeZone/DateTime-TimeZone-0.98.ebuild,v 1.1 2009/09/13 07:58:27 tove Exp $

EAPI="2"

inherit versionator
MY_P=${PN}-$(delete_version_separator 2)
MODULE_AUTHOR=DROLSKY
S=${WORKDIR}/${MY_P}
inherit perl-module

DESCRIPTION="Time zone object base class and factory"

SLOT="0"
KEYWORDS="~x86-freebsd ~amd64-linux ~x86-linux ~x86-macos ~x86-solaris"
IUSE="test"

RDEPEND=">=dev-perl/Params-Validate-0.72
	>=dev-perl/Class-Singleton-1.03"
DEPEND="${RDEPEND}
	>=virtual/perl-Module-Build-0.34
	test? ( >=virtual/perl-Test-Simple-0.92 )"

SRC_TEST="do"
