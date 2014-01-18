#!/usr/bin/env sh
# Make the hawkey SPEC file.
# Usage: ./hawkey-make-spec-in-mock.sh MOCK_CFG
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

MOCK_DIR=/tmp/hawkey-make-spec-in-mock
mock --quiet --root="$1" --chroot "rm --recursive --force '$MOCK_DIR'"
mock --quiet --root="$1" --copyin . "$MOCK_DIR"
mock --quiet --root="$1" --chroot "chown --recursive :mockbuild '$MOCK_DIR'"
mock --quiet --root="$1" --install cmake

mock --quiet --root="$1" --unpriv --shell "cd '$MOCK_DIR'; cmake -P hawkey-make-spec.cmake"; EXIT=$?

mock --quiet --root="$1" --copyout "$MOCK_DIR/package/hawkey.spec" package
exit $EXIT
