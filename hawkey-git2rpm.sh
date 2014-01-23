#!/usr/bin/env sh
# Build the hawkey RPMs from the GIT repository.
# Usage: ./hawkey-git2rpm.sh CFG_DIR MOCK_CFG [DEP_PKG...]
#
# Copyright (C) 2014  Red Hat, Inc.
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of
# the GNU General Public License v.2, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY expressed or implied, including the implied warranties of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.  You should have received a copy of the
# GNU General Public License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.  Any Red Hat trademarks that are incorporated in the
# source code or documentation are not subject to the GNU General Public
# License and may only be used or replicated with the express permission of
# Red Hat, Inc.

# Convert the GIT repository to a source archive.
SRC_DIR=.
git --version >>/dev/null 2>&1; GIT_EXIT=$?
case "$GIT_EXIT" in
	# GIT is installed.
	0) 		GITREV=$(package/archive | tail --lines=1);;
	# GIT is not installed.
	127)	GITREV=$(./hawkey-git2src-in-mock.sh "$1" "$2" | tail --lines=1);;
esac
mv "$HOME/rpmbuild/SOURCES/hawkey-${GITREV}.tar.xz" "$SRC_DIR"

# Make the SPEC file.
SPEC_PATH=package/hawkey.spec
cmake --version >>/dev/null 2>&1; CMAKE_EXIT=$?
case "$CMAKE_EXIT" in
	# cmake is installed.
	0) 		cmake -P hawkey-make-spec.cmake;;
	# cmake is not installed.
	127)	./hawkey-make-spec-in-mock.sh "$1" "$2";;
esac

# Edit the SPEC file.
./hawkey-edit-spec.sh "$SPEC_PATH" "$GITREV"

# Build the SRPM.
SRPM_DIR=.
SRPM_GLOB="$SRPM_DIR"/hawkey-*.src.rpm
rm --force "$SRPM_DIR"/$SRPM_GLOB
mock --quiet --configdir="$1" --root="$2" --buildsrpm --spec "$SPEC_PATH" --sources "$SRC_DIR"
mv "/var/lib/mock/$2/result"/$SRPM_GLOB "$SRPM_DIR"

# Build the RPMs.
./srpm2rpm-with-deps.sh "$SRPM_DIR"/$SRPM_GLOB "$1" "$2" ${*:3}
