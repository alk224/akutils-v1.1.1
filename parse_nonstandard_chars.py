#!/usr/bin/env python
 
## Tony Walters wrote this excellent script.
## It is provided with no warranty or guarantees of any kind!!

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
