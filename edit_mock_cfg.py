#!/usr/bin/env python
# Usage: ./edit_mock_cfg.py --help
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

"""Edit mock configuration files."""


from abc import ABCMeta, abstractmethod
from optparse import OptionParser
from re import compile
from shutil import copyfileobj
from sys import version_info
from tempfile import TemporaryFile


CONFIG_OPTS = b'config_opts'

ENABLE_REPO_VALUE = b'1'


def parse_args():
    usage = 'Usage: ./%prog [options] SOURCE DESTINATION'
    optparser = OptionParser(usage=usage, description=__doc__)
    optparser.add_option(
        '-r', '--root', metavar='CHROOT', help='set the name of the CHROOT')
    optparser.add_option(
        '--enablerepo', action='append', default=[], metavar='ID',
        help='enable repository with ID')
    optparser.add_option(
        '-x', '--exclude', action='append', default=[], metavar='PKG',
        help='exclude PKG from all yum repositories')
    options, arguments = optparser.parse_args()
    if len(arguments) != 2:
        optparser.error('incorrect number of arguments')
    root = None if options.root is None else options.root.encode()
    enablerepo = frozenset(id_.encode() for id_ in options.enablerepo)
    exclude = frozenset(pkg.encode() for pkg in options.exclude)
    return arguments + [root, enablerepo, exclude]


def copy_edited_conf(source, destination, root=None, enablerepo=frozenset(),
                     exclude=frozenset()):
    conf = edit_conf(parse_conf(source), root, enablerepo, exclude)
    write_conf(destination, conf)


def parse_conf(file):
    line = next(file, '')
    while line != '':
        if YumConfigOpt.header_match(line):
            entry = YumConfigOpt.from_header(line)
            entry.sections.extend(parse_yum_conf(file))
        elif ConfigOpt.match(line):
            entry = ConfigOpt.from_bytes(line)
        else:
            assert CONFIG_OPTS not in line
            entry = line
        yield entry
        line = next(file, '')


def parse_yum_conf(file):
    line = next(file)
    while not YumConfigOpt.end_match(line):
        section = YumConfSection.from_header(line)

        line = next(file)
        while not YumConfSection.end_match(line):
            if YumEnableLine.match(line):
                entry = YumEnableLine.from_bytes(line)
            elif YumExcludeLine.match(line):
                entry = YumExcludeLine.from_bytes(line)
            else:
                entry = line
            section.entries.append(entry)
            line = next(file)

        yield section


def edit_conf(entries, root=None, enablerepo=frozenset(), exclude=frozenset()):
    for entry in entries:
        if isinstance(entry, YumConfigOpt):
            # Edit excludes.
            entry_ = YumConfigOpt()
            entry_.sections.extend(
                edit_yum_sections(entry.sections, enablerepo, exclude))
            yield entry_
        elif isinstance(entry, ConfigOpt):
            if root is not None and entry.name == b'root':
                # Edit root.
                value = b''.join((b'\'', root, b'\''))
                yield ConfigOpt(entry.name, value)
            else:
                yield ConfigOpt(entry.name, entry.value)
        elif isinstance(entry, bytes):
            yield entry
        else:
            raise NotImplementedError('unexpected type: {}'.format(type(entry)))


def edit_yum_sections(sections, enablerepo=frozenset(), exclude=frozenset()):
    for section in sections:
        section_ = YumConfSection.from_header(section.header)
        if section.name != b'main':
            entries_ = edit_yum_section_entries(
                section.entries, section.name in enablerepo, exclude)
        else:
            entries_ = section.entries[:]
        section_.entries.extend(entries_)
        yield section_


def edit_yum_section_entries(entries, enable=False, exclude=frozenset()):
    enable_found = exclude_found = False
    for entry in entries:
        if isinstance(entry, YumEnableLine):
            yield YumEnableLine(ENABLE_REPO_VALUE if enable else entry.value)
            enable_found = True
        elif isinstance(entry, YumExcludeLine):
            yield YumExcludeLine(entry.pkgs | exclude)
            exclude_found = True
        elif isinstance(entry, bytes):
            yield entry
        else:
            raise NotImplementedError('unexpected type: {}'.format(type(entry)))
    if not enable_found and enable:
        yield YumEnableLine(ENABLE_REPO_VALUE)
    if not exclude_found and exclude:
        yield YumExcludeLine(exclude)


def write_conf(file, entries):
    file.write(b''.join(bytes(entry) for entry in entries))


class StrMixin(object):

    __metaclass__ = ABCMeta
    
    @abstractmethod
    def __bytes__(self):
        raise NotImplementedError('the method must be implemented')

    def __str__(self):
        bytes_ = self.__bytes__()
        return bytes_.decode('utf-8') if version_info[0] >= 3 else bytes_


class ConfigOpt(StrMixin):
    
    __LEFT = b'[\''

    __LEFT_RE_ESC = b'\[\''

    __RIGHT = b'\'] ='

    __RIGHT_RE_ESC = b'\'\]\s*='

    __REGEX = compile(b''.join(
        (b'^', CONFIG_OPTS, __LEFT_RE_ESC, b'(?P<name>.+)', __RIGHT_RE_ESC,
         b'(?P<value>.*)\n$')))

    def __init__(self, name, value):
        self.name = name
        self.value = value

    def __bytes__(self):
        return b''.join(
            (CONFIG_OPTS, self.__LEFT, self.name, self.__RIGHT, self.value,
             b'\n'))

    @classmethod
    def from_bytes(cls, bytes_):
        name, value = cls.match(bytes_).group('name', 'value')
        return cls(name, value)

    @classmethod
    def match(cls, bytes_):
        return cls.__REGEX.match(bytes_)


class YumConfigOpt(ConfigOpt):

    __HEADER = b''.join((CONFIG_OPTS, b'[\'yum.conf\'] = """\n'))

    __END = b'"""\n'

    def __init__(self):
        super(YumConfigOpt, self).__init__(b'yum.conf', b' """')
        self.sections = []

    def __bytes__(self):
        header = super(YumConfigOpt, self).__bytes__()
        sect_bytes = b''.join((bytes(section) for section in self.sections))
        return b''.join((header, sect_bytes, self.__END))

    @classmethod
    def from_header(cls, header):
        return cls()

    @classmethod
    def header_match(cls, header):
        return header == cls.__HEADER

    @classmethod
    def end_match(cls, end):
        return end == cls.__END


class YumConfSection(StrMixin):

    __HEADER = compile(b'^\[(?P<name>.+)\]\n$')

    def __init__(self, header):
        self.header = header
        self.entries = []

    def __bytes__(self):
        return b''.join(
            [self.header] + [bytes(entry) for entry in self.entries])

    @property
    def name(self):
        return self.header_match(self.header).group('name')

    @classmethod
    def from_header(cls, header):
        return cls(header)

    @classmethod
    def header_match(cls, header):
        return cls.__HEADER.match(header)

    @classmethod
    def end_match(cls, end):
        return cls.header_match(end) or YumConfigOpt.end_match(end)


class YumEnableLine(StrMixin):

    __KEY = b'enabled'

    __KEY_RE_ESC = __KEY

    __SEP = b'='

    __SEP_RE_ESC = __SEP

    __REGEX = compile(b''.join(
        (b'^', __KEY_RE_ESC, b'\s*', __SEP_RE_ESC, b'\s*(?P<value>.*)\n$')))

    def __init__(self, value):
        self.value = value

    def __bytes__(self):
        return b''.join((self.__KEY, self.__SEP, self.value, b'\n'))

    @classmethod
    def from_bytes(cls, bytes_):
        return cls(cls.match(bytes_).group('value'))

    @classmethod
    def match(cls, bytes_):
        return cls.__REGEX.match(bytes_)


class YumExcludeLine(StrMixin):

    __KEY = b'exclude'

    __KEY_RE_ESC = __KEY

    __SEP = b'='

    __SEP_RE_ESC = __SEP

    __PKG_SEP = b' '

    __REGEX = compile(b''.join(
        (b'^', __KEY_RE_ESC, b'\s*', __SEP_RE_ESC, b'\s*(?P<packages>.*)\n$')))

    def __init__(self, pkgs):
        self.pkgs = set(pkgs)

    def __bytes__(self):
        pkgs_bytes = self.__PKG_SEP.join(self.pkgs)
        return b''.join((self.__KEY, self.__SEP, pkgs_bytes, b'\n'))

    @classmethod
    def from_bytes(cls, bytes_):
        return cls(cls.match(bytes_).group('packages').split())

    @classmethod
    def match(cls, bytes_):
        return cls.__REGEX.match(bytes_)


if __name__ == '__main__':
    src_path, dest_path, root, enablerepo, exclude = parse_args()
    with TemporaryFile() as temp_file:
        # Save edited config into a temporary file.
        with open(src_path, 'rb') as src_file:
            copy_edited_conf(src_file, temp_file, root, enablerepo, exclude)
        # Write the temporary file to the destination.
        with open(dest_path, 'wb') as dest_file:
            temp_file.seek(0)
            copyfileobj(temp_file, dest_file)
