#!/usr/bin/env python
#
#  filter_observations_by_sample.py - Filter an OTU table according to counts or fractions within each sample
#
#  Version 1.0.0 (June 5, 2015)
#
#  Copyright (c) 2013-2015 Adam Robbins-Pianka
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
from numpy import array
from biom import load_table, Table

__author__ = "Adam Robbins-Pianka"
__copyright__ = "Copyright 2013"
__credits__ = ["Adam Robbins-Pianka"]
__license__ = "BSD"
__version__ = "0.1.0"
__maintainer__ = "Adam Robbins-Pianka"
__email__ = "adam.robbinspianka@colorado.edu"

parser = ArgumentParser()

parser.add_argument('-i', '--input_biom', help='The path to the input biom '
    'file to be filtered.', required=True)
parser.add_argument('-n', '--abundance_threshold', help='The minimum '
    'abundance of an OTU in a sample in order to be retained.', type=float,
    required=True)
parser.add_argument('-o', '--output_biom', help='The path to the output file.',
    required=True)
parser.add_argument('-f', '--abundance_as_fraction', help='Treat the value '
    'passed for -n (--abundance_threshold) as a fraction rather than an '
    'absolute count.', action='store_true', required=False, default=False)

def main():
    args = parser.parse_args()
    input_fp = args.input_biom
    output_fp = args.output_biom
    threshold = args.abundance_threshold
    as_fraction = args.abundance_as_fraction

    if as_fraction:
        if not 0 <= threshold <= 1:
            raise ValueError("The value passed for -n "
                             "(--abundance_as_fraction) must be in the "
                             "interval [0, 1]")

    if not as_fraction:
        if not str(threshold).replace('.','',1).isdigit():
            raise ValueError("If you want to express the minimum threshold as "
                             "a fraction of the total sequences in a sample, "
                             "use -n in combination with -f. Otherwise, if "
                             "you want to express the minimum threshold as an "
                             "absolute sequence count minimum, the value "
                             "passed for -n must be an integer.")

        threshold = int(threshold)

    input_table = load_table(input_fp)

    new_data = []
    append_new_data = new_data.append
    for abundances in input_table.iter_data():
        if as_fraction:
            abundance_fractions = abundances.astype(float)/sum(abundances)
            indices = [i for (i, j) in enumerate(abundance_fractions>threshold)
                if not j]

        else:
            indices = [i for (i, j) in enumerate(abundances>threshold)
                       if not j]

        item_set = abundances.itemset
        for index in indices:
            item_set(index, 0)

        append_new_data(abundances)

    new_data = array(new_data).transpose()

    new_table = Table(new_data,
                      input_table.ids('observation'),
                      input_table.ids(),
                      input_table.metadata(axis='observation'),
                      input_table.metadata())
    
    with open(output_fp, 'w') as output_fd:
        new_table.to_json('one-time generation', output_fd)


if __name__ == '__main__':
    main()
