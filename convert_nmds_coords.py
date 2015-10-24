#!/usr/bin/env python
#
## Written by Yoshiki, co-opted by Andrew.
## See https://groups.google.com/forum/#!searchin/qiime-forum/nmds$20emperor/qiime-forum/CtiCy1vJao8/7jBSlCniCQAJ
## and https://gist.github.com/ElDeveloper/dabccfb9024378262549
#  Version 1.0.0 (October 22, 2015)
#
#  Copyright (c) 2014-2015 Yoshiki Vazquez-Baeza
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

from argparse import ArgumentParser
import sys

parser = ArgumentParser(description='Converts output from nmds.py so that it can be used for input with make_emperor.py')
parser.add_argument('-i', '--input_nmds', help='The path to the input nmds coordinates file to be filtered (output from nmds.py).', action='store', required=True)
parser.add_argument('-o', '--corrected_output', help='The path to the desired output file name.', required=True)

args = parser.parse_args()
input_fp = args.input_nmds
output_fp = args.corrected_output

if len(sys.argv)<=1:
    parser.print_help()
    sys.exit(1)

# USE AT YOUR OWN RISK
# first argument is file to convert, second argument is file to
# write the converted output to

with open(input_fp, 'r') as f, open(output_fp, 'w') as g:
    for line in f:
        if line.startswith('samples'):
            g.write(line.replace('samples', 'pc vector number'))

        # inflate the values so emperor won't complain about them being
        # too small
        elif line.startswith('stress'):
            x = line.split('\t')
            g.write('eigvals\t%s\n' % '\t'.join(['1']*(len(x)-1)))
        elif line.startswith('% variation explained'):
            x = line.split('\t')
            g.write('%% variation explained\t%s\n' % '\t'.join(['1']*(len(x)-1)))
        else:
            g.write(line)

