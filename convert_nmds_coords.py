#!/usr/bin/env python

## Written by Yoshiki.
## See https://groups.google.com/forum/#!searchin/qiime-forum/nmds$20emperor/qiime-forum/CtiCy1vJao8/7jBSlCniCQAJ
## and https://gist.github.com/ElDeveloper/dabccfb9024378262549
from sys import argv

# USE AT YOUR OWN RISK
# first argument is file to convert, second argument is file to
# write the converted output to
with open(argv[1]) as f, open(argv[2], 'w') as g:
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
