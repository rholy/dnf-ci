#!/usr/bin/env sh
# Fix the order of libcomps changelog entries.
# Usage: ./libcomps-fix-changelog-in-mock.sh SRC_PATH DEST_PATH MOCK_CFG
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

MOCK_DIR=/tmp/libcomps-fix-changelog-in-mock
MOCK_SRC="$MOCK_DIR/$(basename $1)"
MOCK_DEST="$MOCK_SRC-fixed"
mock --quiet --root="$3" --chroot "mkdir --parents '$MOCK_DIR'"
mock --quiet --root="$3" --copyin "$1" libcomps_fix_changelog.py "$MOCK_DIR"
mock --quiet --root="$3" --chroot "chown --recursive :mockbuild '$MOCK_DIR'"
mock --quiet --root="$3" --install python

mock --quiet --root="$3" --unpriv --shell "cd '$MOCK_DIR' && ./libcomps_fix_changelog.py '$MOCK_SRC' '$MOCK_DEST'"; EXIT=$?

rm --force "$2"
mock --quiet --root="$3" --copyout "$MOCK_DEST" "$2"
exit $EXIT
