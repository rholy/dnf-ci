#!/usr/bin/env sh
# Build the libcomps RPMs from the GIT repository.
# Usage: ./libcomps-git2rpm.sh MOCK_CFG [DEP_PKG...]
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

# Convert the GIT repository to a source archive and make the SPEC file.
git --version >>/dev/null 2>&1; GIT_EXIT=$?
case "$GIT_EXIT" in
	# GIT is installed.
	0) 		IS_GIT=0;;
	# GIT is not installed.
	127)	IS_GIT=1;;
esac
cmake --version >>/dev/null 2>&1; CMAKE_EXIT=$?
case "$CMAKE_EXIT" in
	# cmake is installed.
	0) 		IS_CMAKE=0;;
	# cmake is not installed.
	127)	IS_CMAKE=1;;
esac
if [ $(($IS_GIT + $IS_CMAKE)) -eq 0 ]; then
	./build_prep.sh;
else
	./libcomps-git2src-make-spec-in-mock.sh "$1"
fi
SRC_DIR=.
SPEC_PATH=libcomps.spec

# Fix "%changelog not in descending chronological order".
python --version >>/dev/null 2>&1; PYTHON_EXIT=$?
case "$PYTHON_EXIT" in
	# Python is installed.
	0) 		./libcomps_fix_changelog.py "$SPEC_PATH" "$SPEC_PATH";;
	# Python is not installed.
	127)	./libcomps-fix-changelog-in-mock.sh "$SPEC_PATH" "$SPEC_PATH" "$1";;
esac

# Build the SRPM.
SRPM_DIR=.
SRPM_GLOB="$SRPM_DIR"/libcomps-*.src.rpm
rm --force "$SRPM_DIR"/$SRPM_GLOB
mock --quiet --root="$1" --buildsrpm --spec "$SPEC_PATH" --sources "$SRC_DIR"
mv "/var/lib/mock/$1/result"/$SRPM_GLOB "$SRPM_DIR"

# Build the RPMs.
./srpm2rpm-with-deps.sh "$SRPM_DIR"/$SRPM_GLOB "$1" python-sphinx python3-sphinx ${*:2} # python-sphinx python3-sphinx (Fix of python2: can't open file 'SPHINX_EXECUTABLE-NOTFOUND': [Errno 2] No such file or directory)
