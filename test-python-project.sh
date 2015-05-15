#!/usr/bin/env sh
# Run python tests.
# Usage: ./test-python-project.sh PYTHON_VERSION PYTHONPATH
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

export PYTHONPATH="$2:$PYTHONPATH"

# Run tests with default environment.
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
nosetests-$1 --quiet tests; EXIT1=$?

# Run tests with cs locale.
export LANG=cs_CZ.utf8
export LC_ALL=cs_CZ.utf8
nosetests-$1 --quiet tests; EXIT2=$?

# Run tests without capturing the output.
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
nosetests-$1 --quiet --nocapture tests; EXIT3=$?

exit $(($EXIT1 + $EXIT2 + $EXIT3))
