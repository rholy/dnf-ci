#!/usr/bin/env sh
# Test python 3 code.
# Usage: ./test-python3-code.sh
#
# Copyright (C) 2014-2015  Red Hat, Inc.
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

mkdir build
pushd build
cmake ..
popd

python3 -m pep8 . > pep8.log 2>&1; PEP_EXIT=$?
python3-pyflakes . > pyflakes.log 2>&1; PYFLAKES_EXIT=$?
PYLINT_EXIT=0
rm --force pylint.log
for SUBDIR in */; do
	pylint --msg-template="{path}:{line}: [{msg_id}({symbol}), {obj}] {msg}" "./$SUBDIR" >> pylint.log 2>&1; PYLINT_EXIT=$(($PYLINT_EXIT | $?))  # According to man pages, they can be ORed.
done
exit $(($PEP_EXIT + $PYFLAKES_EXIT + $PYLINT_EXIT))
