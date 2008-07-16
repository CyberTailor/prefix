# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-haskell/stm/stm-2.1.1.0.ebuild,v 1.3 2008/07/15 16:25:48 jer Exp $

EAPI="prefix"

CABAL_FEATURES="lib profile haddock"
CABAL_MIN_VERSION=1.2
inherit haskell-cabal

DESCRIPTION="Software Transactional Memory"
HOMEPAGE="http://haskell.org/ghc/"
SRC_URI="http://hackage.haskell.org/packages/archive/${PN}/${PV}/${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64-linux ~x86-linux ~x86-macos"
IUSE=""

DEPEND=">=dev-lang/ghc-6.8"
