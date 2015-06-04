#!/usr/bin/env python
#
#  parse_nonstandard_chars.py - removes any characters that are not ASCII 127
#
#  Version 1.0.0 (June 5, 2015)
#
#  Copyright (c) 2014-2015 Tony Walters
#
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event will the authors be held liable for any damages
#  arising from the use of this software.
#
#  Permission is granted to anyone to use this software for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not
#     claim that you wrote the original software. If you use this software
#     in a product, an acknowledgment in the product documentation would be
#     appreciated but is not required.
#  2. Altered source versions must be plainly marked as such, and must not be
#     misrepresented as being the original software.
#  3. This notice may not be removed or altered from any source distribution.
#

"""Somewhat hackish way to eliminate non-ASCII characters in a text file,
such as a taxonomy mapping file, with QIIME. Reads through the file, and 
removes all characters above decimal value 127. Additionally, asterisk "*"
characters are removed, as these inhibit the RDP classifier.

Usage:
python parse_nonstandard_chars.py X > Y
where X is the input file to be parsed, and Y is the output parsed file"""
 
from sys import argv
 
 
taxa_mapping = open(argv[1], "U")
 
for line in taxa_mapping:
    curr_line = line.strip()
 
    try:
        curr_line.decode('ascii')
        if "*" in curr_line:
            raise(ValueError)
        print curr_line
    except:
        fixed_line = ""
        for n in curr_line:
            if ord(n) < 128 and n != "*":
                fixed_line += n
        print fixed_line
