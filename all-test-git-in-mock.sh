#!/usr/bin/env sh
# Test all projects and code using given configuration.
# Usage: ./all-test-git-in-mock.sh CFG_PATH SKIP_LINT
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

MOCK_CFG=$(basename "$1" | sed 's/.cfg$//')-excl
RPMS_DIR=.
RPMS_SUFFIX=.rpm
echo "Testing all projects and code using $MOCK_CFG.cfg..."

# Initialize the modified mock.
echo "Initializing the $MOCK_CFG mock..."
cp /etc/mock/site-defaults.cfg .
cp /etc/mock/logging.ini .
./edit_mock_cfg.py --root="$MOCK_CFG" --enablerepo=updates-testing --exclude=hawkey --exclude=librepo --exclude=libcomps --exclude=dnf "$1" "$MOCK_CFG.cfg"
mock --quiet --configdir=. --root="$MOCK_CFG" --init
echo "...initialization done."

# Build hawkey.
echo "Building hawkey RPMs from the GIT repository in $MOCK_CFG mock..."
cd hawkey
./hawkey-git2rpm.sh .. "$MOCK_CFG" "../$RPMS_DIR"/*"$RPMS_SUFFIX"; HAWKEY_EXIT=$?
mv "/var/lib/mock/$MOCK_CFG/result"/*hawkey-*"$RPMS_SUFFIX" "../$RPMS_DIR"
mv "/var/lib/mock/$MOCK_CFG/result/installed_pkgs" ../hawkey-installed_pkgs
mv "/var/lib/mock/$MOCK_CFG/result/build.log" ../hawkey-build.log
cd ..
if [ $HAWKEY_EXIT -eq 0 ]; then
	echo "...build succeeded."
else
	echo "...build failed with $HAWKEY_EXIT."
fi

# Build librepo.
echo "Building librepo RPMs from the GIT repository in $MOCK_CFG mock..."
cd librepo
./librepo-git2rpm-in-mock.sh .. "$MOCK_CFG" "../$RPMS_DIR"/*"$RPMS_SUFFIX" > ../librepo-build.log 2>&1; LIBREPO_EXIT=$?
mv librepo-*.src"$RPMS_SUFFIX" "../$RPMS_DIR"
mv "$HOME/rpmbuild/RPMS"/*librepo-*"$RPMS_SUFFIX" "../$RPMS_DIR"
cd ..
if [ $LIBREPO_EXIT -eq 0 ]; then
	echo "...build succeeded."
else
	echo "...build failed with $LIBREPO_EXIT."
fi

# Build libcomps.
echo "Building libcomps RPMs from the GIT repository in $MOCK_CFG mock..."
cd libcomps
./libcomps-git2rpm.sh .. "$MOCK_CFG" "../$RPMS_DIR"/*"$RPMS_SUFFIX"; LIBCOMPS_EXIT=$?
mv "/var/lib/mock/$MOCK_CFG/result"/*libcomps-*"$RPMS_SUFFIX" "../$RPMS_DIR"
mv "/var/lib/mock/$MOCK_CFG/result/installed_pkgs" ../libcomps-installed_pkgs
mv "/var/lib/mock/$MOCK_CFG/result/build.log" ../libcomps-build.log
cd ..
if [ $LIBCOMPS_EXIT -eq 0 ]; then
	echo "...build succeeded."
else
	echo "...build failed with $LIBCOMPS_EXIT."
fi

# Build dnf.
echo "Building dnf RPMs from the GIT repository in $MOCK_CFG mock..."
BUILD2_DIR=build-py2
BUILD3_DIR=build-py3
cd dnf
./dnf-git2rpm.sh .. "$MOCK_CFG" "../$RPMS_DIR"/*"$RPMS_SUFFIX"; DNF_EXIT=$?
rm --recursive --force "../$BUILD2_DIR" "../$BUILD3_DIR"
mock --quiet --configdir=.. --root="$MOCK_CFG" --copyout /builddir/build/BUILD/dnf "../$BUILD2_DIR"
mv "../$BUILD2_DIR/py3" "../$BUILD3_DIR"
mv "/var/lib/mock/$MOCK_CFG/result"/*dnf-*"$RPMS_SUFFIX" "../$RPMS_DIR"
mv "/var/lib/mock/$MOCK_CFG/result/installed_pkgs" ../dnf-installed_pkgs
mv "/var/lib/mock/$MOCK_CFG/result/build.log" ../dnf-build.log
cd ..
if [ $DNF_EXIT -eq 0 ]; then
	echo "...build succeeded."
else
	echo "...build failed with $DNF_EXIT."
fi

# Test builds.
echo "Running tests in $MOCK_CFG mock..."
mock --quiet --configdir=. --root="$MOCK_CFG" --init
mock --quiet --configdir=. --root="$MOCK_CFG" --install "$RPMS_DIR"/*"$RPMS_SUFFIX"
cd "$BUILD2_DIR"
cp ../test-python-project.sh ../test-python2-code.sh .
../test-python-project-in-mock.sh 2.7 .. "$MOCK_CFG" > ../python2-tests.log 2>&1; TESTS2_EXIT=$?
../test-python2-code-in-mock.sh .. "$MOCK_CFG"; LINT2_EXIT=$?
mv pep8.log ../python2-pep8.log
sed --in-place "s,^\./\([^:]\+:[0-9]\+:.*\),dnf/\1," ../python2-pep8.log
mv pyflakes.log ../python2-pyflakes.log
sed --in-place "s,^\./\([^:]\+:[0-9]\+:.*\),dnf/\1," ../python2-pyflakes.log
mv pylint.log ../python2-pylint.log
sed --in-place "s,^[^:]\+:[0-9]\+:,dnf/\0," ../python2-pylint.log
cd "../$BUILD3_DIR"
cp ../test-python-project.sh ../test-python3-code.sh .
../test-python-project-in-mock.sh 3.3 .. "$MOCK_CFG" > ../python3-tests.log 2>&1; TESTS3_EXIT=$?
../test-python3-code-in-mock.sh .. "$MOCK_CFG"; LINT3_EXIT=$?
mv pep8.log ../python3-pep8.log
sed --in-place "s,^\./\([^:]\+:[0-9]\+:.*\),dnf/\1," ../python3-pep8.log
mv pyflakes.log ../python3-pyflakes.log
sed --in-place "s,^\./\([^:]\+:[0-9]\+:.*\),dnf/\1," ../python3-pyflakes.log
mv pylint.log ../python3-pylint.log
sed --in-place "s,^[^:]\+:[0-9]\+:,dnf/\0," ../python3-pylint.log
cd ..
TESTS_EXIT=$(($TESTS2_EXIT + $TESTS3_EXIT))
TESTS_EXIT_STR="$TESTS2_EXIT and $TESTS3_EXIT"
if [ $2 -ne 1 ]; then
    TESTS_EXIT=$(($TESTS_EXIT + $LINT2_EXIT + $LINT3_EXIT))
    TESTS_EXIT_STR="$TESTS_EXIT_STR and $LINT2_EXIT and $LINT3_EXIT"
fi
if [ $TESTS_EXIT -eq 0 ]; then
	echo "...test succeeded."
else
	echo "...test failed with $TESTS_EXIT_STR."
fi

EXIT=$(($HAWKEY_EXIT + $LIBREPO_EXIT + $LIBCOMPS_EXIT + $DNF_EXIT + $TESTS_EXIT))
if [ $EXIT -eq 0 ]; then
	echo "...test succeeded."
else
	echo "...test failed with $EXIT."
fi
exit $EXIT
