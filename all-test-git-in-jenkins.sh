#!/usr/bin/env sh
# Test all projects and code within a Jenkins environment.
# Usage: ./all-test-git-in-jenkins.sh
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

MOCK_CFGS=(fedora-21-x86_64-dnf.cfg fedora-21-i386-dnf.cfg)
IGNORE_LINT=1
ARTIFACTS_SUFFIX=-build
PEP_SUFFIX=-pep8.log
PYFLAKES_SUFFIX=-pyflakes.log
PYLINT_SUFFIX=-pylint.log

# Place all scripts required by the code below and by the scripts themselves.
cp dnf-ci/hawkey-git2rpm.sh dnf-ci/hawkey-edit-spec.sh hawkey
cp dnf-ci/librepo-git2rpm-in-mock.sh dnf-ci/librepo-git2rpm.sh dnf-ci/librepo-edit-spec.sh dnf-ci/librepo-edit-make_rpm.sh librepo
cp dnf-ci/libcomps-git2rpm.sh dnf-ci/libcomps-git2src-make-spec-in-mock.sh dnf-ci/libcomps-edit-spec.sh dnf-ci/srpm2rpm-with-deps.sh libcomps
cp dnf-ci/dnf-git2rpm.sh dnf
cp dnf-ci/dnf-plugins-git2rpm.sh dnf-ci/dnf-plugins-git2src-in-mock.sh dnf-ci/dnf-plugins-git2src.sh dnf-ci/dnf-plugins-edit-spec.sh dnf-ci/srpm2rpm-with-deps.sh dnf-plugins-core
cp dnf-ci/test-python-project-in-mock.sh dnf-ci/test-python-project.sh dnf-ci/test-python2-code-in-mock.sh dnf-ci/test-python2-code.sh dnf-ci/test-python3-code-in-mock.sh dnf-ci/test-python3-code.sh .

rm --recursive --force *"$ARTIFACTS_SUFFIX"

EXIT=0
for MOCK_CFG in "${MOCK_CFGS[@]}"; do
    cp "dnf-ci/$MOCK_CFG" .
    dnf-ci/all-test-git-in-mock.sh "$MOCK_CFG" "$BUILD_NUMBER" "$IGNORE_LINT"; EXIT=$(($EXIT + $?))

    ARTIFACTS_DIR=$(basename "$MOCK_CFG" | sed 's/-dnf.cfg$//')"$ARTIFACTS_SUFFIX"
    mkdir --parents "$ARTIFACTS_DIR"
    mv *.rpm *"$PEP_SUFFIX" *"$PYFLAKES_SUFFIX" *"$PYLINT_SUFFIX" "$ARTIFACTS_DIR"
    createrepo "$ARTIFACTS_DIR"
done

OLD_REPOS=(fedora-20-x86_64-build fedora-20-i386-build)
for REPO in "${OLD_REPOS[@]}"; do
    mkdir "$REPO"
    createrepo "$REPO"
done

exit $EXIT
