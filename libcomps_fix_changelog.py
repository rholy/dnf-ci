#!/usr/bin/env python
# Usage: ./libcomps_fix_changelog.py --help
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

"""Fix the order of libcomps changelog entries."""


from logging import error
from operator import attrgetter
from optparse import OptionParser
from re import compile
from shutil import copyfileobj
from sys import exit, version_info
from tempfile import TemporaryFile
from time import strptime


CHANGELOG_START = b'%changelog\n'

CHANGELOG_SEPARATOR = b'\n'

CHANGELOG_END = b'\n'


def parse_args():
    usage = 'Usage: ./%prog SOURCE DESTINATION'
    optparser = OptionParser(usage=usage, description=__doc__)
    _options, arguments = optparser.parse_args()
    if len(arguments) != 2:
        optparser.error('incorrect number of arguments')
    return arguments


def copy_lines_until(source, destination, stop_line):
    line = next(source, stop_line)
    while line != stop_line:
        destination.write(line)
        line = next(source, stop_line)


def copy_fixed_changelog(source, destination):
    write_changelog(destination, fix_changelog(parse_changelog(source)))


def parse_changelog(file):
    line = next(file)
    while line != CHANGELOG_END:
        entry = ChangelogEntry(line)

        line = next(file)
        while line != CHANGELOG_SEPARATOR:
            entry.items.append(line)
            line = next(file)

        yield entry
        line = next(file)


def fix_changelog(entries):
    original = list(entries)
    fixed = sorted(original, key=attrgetter('date'), reverse=True)
    if original == fixed:
        raise ValueError('changelog is correct')
    return fixed


def write_changelog(file, entries):
    file.write(CHANGELOG_START)
    file.write(CHANGELOG_SEPARATOR.join(bytes(entry) for entry in entries))
    file.write(CHANGELOG_END)


class ChangelogEntry(object):

    HEADER = compile(
        b'^\* (?P<date>[A-Z][a-z]{2} [A-Z][a-z]{2} \d{2} \d{4}) '
        b'(?P<author>\S+ \S+) <(?P<email>[^>]+)> (?P<version>.+)\n$')

    def __init__(self, header):
        self.header = header
        self.items = []

    def __bytes__(self):
        return b''.join([self.header] + self.items)

    def __str__(self):
        bytes_ = self.__bytes__()
        return bytes_.decode('utf-8') if version_info[0] >= 3 else bytes_

    @property
    def date(self):
        date_bytes = self.HEADER.match(self.header).group('date')
        date_string = date_bytes.decode('utf-8')
        return strptime(date_string, '%a %b %d %Y')


if __name__ == '__main__':
    src_path, dest_path = parse_args()
    with TemporaryFile() as temp_file:
        # Save fixed spec into a temporary file.
        with open(src_path, 'rb') as src_file:
            copy_lines_until(src_file, temp_file, CHANGELOG_START)
            try:
                copy_fixed_changelog(src_file, temp_file)
            except ValueError:
                error('changelog does not need to be fixed')
                exit(1)
            copy_lines_until(src_file, temp_file, None)
        # Write the temporary file to the destination.
        with open(dest_path, 'wb') as dest_file:
            temp_file.seek(0)
            copyfileobj(temp_file, dest_file)
