#!/usr/bin/env python
from __future__ import division

__author__ = "Greg Caporaso"
__copyright__ = "Copyright 2010, The PrimerProspector project"
__credits__ = ["William A. Walters", "Greg Caporaso", "Rob Knight"]
__license__ = "GPL"
__version__ = "1.0.2-dev"
__maintainer__ = "William A. Walters"
__email__ = "william.a.walters@colorado.edu"
__status__ = "Development"

""" Description
File created on 18 Mar 2009.
Modified by William Walters 25 Aug 2009.

The purpose of this module is to score primers for their ability to 
amplify target DNA sequences.

This module takes an input primer file and one or more fasta files.  Each
primer is tested against every sequence to find the best local alignment.
Mismatches and gaps are calculated for the primer, with a weighting giving
larger penalties to gaps and mismatches in the 3' end of the primer.

An output hits file is generated for each primer, recording information about
the primer hit site, mismatches, and overall weighted score (a perfect score
starts at zero and increases as penalties are added).  A graph is
also generated, showing mismatch/gap and overall score information for the 
primer and the target sequences.

The primers input file should be generated with the following format:
Comments are preceeded by a pound "#" symbol.
The primer data are tab delineated with the primer name first, such as
"349_v2r", the actual nucleotide sequence next, listed in a 5' to 3' sequence, 
(example: "AATCGRACGNTYA"), and finally a comment 
or citation, if any, can be listed.  Forward primers should be followed by a 
"f" while reverse primers are followed by "r".
A complete example line is listed below.
815_v34f    GTGGCCNATRRCYAGAACGC    Darrow,Scopes,Bryan et al. 1926

The input sequences should be in fasta format.  If more than one file is 
supplied, they should be separated by a colon.

"""


from os.path import basename
from string import lower, upper
from math import ceil
import warnings
warnings.filterwarnings('ignore', 'Not using MPI as mpi4py not found')

from matplotlib import use
use ("Agg")
from pylab import plot, savefig, xlabel, ylabel, text,\
    hist, figure, title, xlim, ylim, xticks, yticks,\
    subplot, clf, close, subplots_adjust
from cogent import LoadSeqs, DNA
from cogent.core.moltype import IUPAC_DNA_ambiguities
from cogent.core.alphabet import AlphabetError
from cogent.align.align import make_dna_scoring_dict, local_pairwise
from cogent.parse.fasta import MinimalFastaParser
from numpy import arange

from primerprospector.parse import parse_formatted_primers_data,\
 get_fasta_filepaths
from primerprospector.util import correct_primer_name

#####
# Start input/output handling functions
#####     


    
    
def get_outf_paths(output_dir, 
                   primer, 
                   fasta_filepath):
    """ Returns output .ps and hits file name based on primer, fasta_fp name
    
    output_dir: directory where primer hits and graphs will be written
    primer: DNA.Sequence object containing primer sequence, name
    fasta_filepath: fasta filepath against which primer is tested."""
    
    graph_out_fp = output_dir + "/" + primer.Name + "_" +\
     basename(fasta_filepath).split('.')[0] + ".ps"
    hits_out_fp = output_dir + "/" + primer.Name + "_" +\
     basename(fasta_filepath).split('.')[0] + "_hits.txt"
    
    return graph_out_fp, hits_out_fp
    
         
#####
# End input/output handling functions
#####
 
#####
# Start graphing functions
#####  

def primer_hit_histogram(data,
                         figure_title,
                         x_label,
                         bin_size=1,
                         y_label='Count',
                         max_cap = 5,
                         y_axis_size=None):
    """ Build and write primer mismatch/gaps/score histograms
    
        data: list of values (i.e., mismatches) for each sequence
        figure_title: string passed to title()
        x_label: string passed to xlabel()
        bin_size: width of the bins to be plotted, for discrete values, such
         as gap/mismatch counts, should be set to 1
        y_label: Should always be 'Count' for bin values
        max_cap: Used to set a max value for the bins, makes graphs more
         consistent for easier comparisons between graphs.  If set to False,
         will use the actual max value in the data for determing xticks and
         x labels.
        y_axis_size: If specified, will set the size of the y-axis.  If not
         specified, will be set according to max size of current data set.
        
    """
    
    # Set x and y labels
    xlabel(x_label, size='x-small')
    ylabel(y_label, size='x-small')
    
    # Sticking with red color for now
    color = 'r'

    # Find the limits which will be used to define bins and axes
    # Note-using a False max_cap value can lead to odd results in how float
    # values are displayed.  Use at your own risk.  Also, bin_size values
    # need to be small enough to accommodate any possible value, so you have to 
    # effectively calculate the least common multiple float value for all
    # elements of the input data list.
    
    min_x = 0
    if max_cap:
        max_x = max_cap
    else:
        max_x = int(round(max(data)))+1
    
    if max_cap:
        max_bin = max_cap + 2
    else:
        max_bin = max_x + 1
    
        
    # Create bins
    counts, bins, rects = \
     hist(data, bins=arange(0, max_bin, bin_size),\
     rwidth=0.25, ec=color, fc=color)
     
    # Needs to be of type int to avoid errors with newer versions of Matplotlib
    max_data_points = int(max(counts))

    # Generate x axis values, labels
    if max_cap:
        x_tick_step = int(0.1*abs(max_x-min_x)) or 1
        x_axis_values= 0.5 + arange(0, int(max_bin), bin_size) 
    else:
        x_tick_step = bin_size
        x_axis_values= 0.5 + arange(0, int(max_bin), bin_size) 

    
    if max_cap:
        x_axis_labels = range(0, max_cap+1)
        # Set last value of x axis labels to have a "+" following it to 
        # indicate cap
        x_axis_labels[-1] = str(x_axis_labels[-1]) + "+"
    else:
        x_axis_labels = arange(0, int(max_bin), bin_size)
        
    xticks(x_axis_values, x_axis_labels, size=7)
    xlim(min_x, max_x+1)
    
    if y_axis_size:
        # Use predetermined max size
        y_tick_step = int(0.2*y_axis_size) or 2
        yticks(range(0, y_axis_size+2, y_tick_step), size=7)
        ylim(0, y_axis_size)
    else:
        # Use max size of current data set
        y_tick_step = int(0.2*max_data_points) or 2
        yticks(range(0, max_data_points+2, y_tick_step), size=7)
        ylim(0, max_data_points)
        
        
    
def write_primer_histogram(hist_data,
                           graph_filepath):
    """ Writes histogram from input list of hits data, title/subtitle 
    
    hist_data: histogram data, list of data for different components of the
     output histogram
    graph_filepath: output filepath.
    """
    
    # indices of lists for histogram data
    non_tp_mm_data_index = 0
    tp_mm_data_index = 1
    non_tp_gap_data_index = 2
    tp_gap_data_index = 3
    weighted_score_index = 4
    last_base_index = 5
    figure_title_index = 6
    weighted_score_subtext_index = 7

    
    
    # Setting for matplotlib figures
    figure_num = 0
    figure_title = hist_data[figure_title_index]
    weighted_score_subtext = hist_data[weighted_score_subtext_index]
    
    # build output plot as a single plot with subplots
    # increased figsize in modified form
    f = figure(figure_num,figsize=(8, 10))

    # Plot title and subtext for weighted score
    f.text(.5, .93, figure_title, horizontalalignment='center')
    f.text(.5, .12, weighted_score_subtext, horizontalalignment='center',
     fontsize='small')
     
    # Need to determine the largest bin before generating subplots to have
    # consistent y-axis size, also need to round up, and make int as newer versions of
    # matplotlib will not handle float values as this parameter.
    y_axis_max = \
     int(ceil(get_yaxis_max(hist_data[non_tp_mm_data_index:figure_title_index])))
    
    
    # Plot 3', non 3' mismatches, gaps, and overall weighted scores
    subplot(7, 1, 1)
    primer_hit_histogram(hist_data[non_tp_mm_data_index], '',
     'Non 3\' mismatches', y_axis_size=y_axis_max)

    subplot(7, 1, 2)
    primer_hit_histogram(hist_data[tp_mm_data_index], '', '3\' mismatches',
     y_axis_size=y_axis_max)
     
    subplot(7, 1, 3)
    primer_hit_histogram(hist_data[last_base_index], '', 
     'Final 3\' base mismatches', y_axis_size=y_axis_max)
    
    subplot(7, 1, 4)
    primer_hit_histogram(hist_data[non_tp_gap_data_index], '', 'Non 3\' gaps',
     y_axis_size=y_axis_max)
    
    subplot(7, 1, 5)
    primer_hit_histogram(hist_data[tp_gap_data_index], '', '3\' gaps',
     y_axis_size=y_axis_max)
    
    subplot(7, 1, 6)
    # Get rounded data for displaying easily read graph
    rounded_weighted_score_data =\
     [round(x) for x in hist_data[weighted_score_index]]
    primer_hit_histogram(rounded_weighted_score_data, '', 'Weighted Score',
     y_axis_size=y_axis_max)
    
    subplots_adjust(hspace=0.5)

    savefig(graph_filepath, dpi = 300)

    # If a large number of sequences/primers are tested, need to clear memory
    # to prevent crashing
    clf()
    close()
    
    
#####
# End graphing functions
#####

#####
# Start primer handling functions
#####

def primer_to_match_query(primer):
    """Convert a forward or reverse primer to match the plus strand of a seq
    
    primer: Sequence object containing primer sequence and name
    """
    '''if primer.Name.endswith('f'):
        query_primer = str(primer)
    elif primer.Name.endswith('r'):
        query_primer = str(primer.rc())
    else:
        raise ValueError,\
         "Primer name must end with 'f' or 'r' to indicate forward or reverse."
    return query_primer'''
    
    if primer.Name.split("_")[0].endswith('f'):
        query_primer = str(primer)
    elif primer.Name.split("_")[0].endswith('r'):
        query_primer = str(primer.rc())
    else:
        raise ValueError,\
         '%s not named correctly, all primers ' % primer.Name +\
         'must start with an alphanumeric value '+\
         'followed by "f" or "r".  Any underscores should occur after this '+\
         'name.  Example: 219f_bacterial'
    return query_primer
         


#####
# End primer handling functions
#####


    
#####
# Start mismatch counting functions
#####

def match_scorer_ambigs(match=1,
                       mismatch=-1,
                       matches=None):
    """ Alternative scorer factory for sw_align, allows match to ambiguous chars

    It allows for matching to ambiguous characters which is useful for 
     primer/sequence matching. Not sure what should happen with gaps, but they
     shouldn't be passed to this function anyway. Currently a gap will only match
     a gap.

    match and mismatch should both be numbers. Typically, match should be 
    positive and mismatch should be negative.

    Resulting function has signature f(x,y) -> number.
    
    match: score for nucleotide match
    mismatch: score for nucleotide mismatch
    matches: dictionary for matching nucleotides, including degenerate bases
    """
    
    matches = matches or \
     {'A':{'A':None},'G':{'G':None},'C':{'C':None},\
      'T':{'T':None},'-':{'-':None}}
    for ambig, chars in IUPAC_DNA_ambiguities.items():
        try:
            matches[ambig].update({}.fromkeys(chars))
        except KeyError:
            matches[ambig] = {}.fromkeys(chars)
        
        for char in chars:
            try:
                matches[char].update({ambig:None})
            except KeyError:
                matches[char] = {ambig:None}
            
    def scorer(x, y):
        # need a better way to disallow unknown characters (could
        # try/except for a KeyError on the next step, but that would only 
        # test one of the characters)
        if x not in matches or y not in matches:
            raise ValueError, "Unknown character: %s or %s" % (x,y)
        if y in matches[x]:
            return match
        else:
            return mismatch
    return scorer
    



def pair_hmm_align_unaligned_seqs(seqs,
                                  moltype=DNA,
                                  params={}):
    """
        Handles pairwise alignment of given sequence pair
        
        seqs: list of [primer, target sequence] in string format
        moltype: molecule type tested.  Only DNA supported.
        params: Used to set parameters for opening, extending gaps  and score
         matrix if something other than the default given in this function 
         is desired.
    """
    
    try:
        seqs = LoadSeqs(data=seqs,moltype=moltype,aligned=False)
    except AlphabetError:
        raise AlphabetError,("Error in characters present in primer "+\
         "%s and/or sequence %s." % (seqs[0], seqs[1]))
    try:
        s1, s2 = seqs.values()
    except ValueError:
        raise ValueError,\
         "Pairwise aligning of seqs requires exactly two seqs."
    
    try:
        gap_open = params['gap_open']
    except KeyError:
        gap_open = 5
    try:
        gap_extend = params['gap_extend']
    except KeyError:
        gap_extend = 2
    try:
        score_matrix = params['score_matrix']
    except KeyError:
        score_matrix = make_dna_scoring_dict(\
         match=1, transition=-1, transversion=-1)
    
    return local_pairwise(s1, s2, score_matrix, gap_open, gap_extend)


def local_align_primer_seq(primer,
                           sequence):
    """Perform local alignment of primer and sequence
    
        primer: Current primer being tested
        sequence: Current sequence
        
        Returns the Alignment object primer sequence and target sequence, 
         and the start position in sequence of the hit.
    """


    query_sequence = sequence
     
    # Get alignment object from primer, target sequence
    alignment = pair_hmm_align_unaligned_seqs([primer,query_sequence])

    # Extract sequence of primer, target site, may have gaps in insertions
    # or deletions have occurred.
    primer_hit = str(alignment.Seqs[0])
    target_hit = str(alignment.Seqs[1])
    
    # Get index of primer hit in target sequence.
    try:
        hit_start = query_sequence.index(target_hit.replace('-',''))
    except ValueError:
        raise ValueError,('substring not found, query string %s, target_hit %s'\
         % (query_sequence, target_hit))
         
    
    return primer_hit, target_hit, hit_start
   

def score_primer(primer,
                 primer_hit,
                 target_hit,
                 tp_len,
                 last_base_mm,
                 tp_mm,
                 non_tp_mm,
                 tp_gap,
                 non_tp_gap,
                 sw_scorer=match_scorer_ambigs(1, -1)):
    """ Gets mismatches and gaps, for given primer hit and seq hit
    
    Specifically, this function returns the 3' and non 3' gaps and mismatches
    for a given primer and target hit alignment objects, as well as weighted
    score.
    
    primer: Current primer sequence object being tested.
    primer_hit: Alignment object for primer, normally matches primer unless
     gaps were used in the alignment
    target_hit: Alignment object for segment of sequence where primer was
     aligned to.  Can contain gaps.
    tp_len: three prime length
    last_base_mm: penalty for last base mismatch
    tp_mm: three prime mismatch penalty
    non_tp_mm: non three prime mismatch penalty
    tp_gap: penalty for three prime gaps
    non_tp_gap: penalty for non three prime gaps
    sw_scorer: Gives scores for mismatches, gap insertions in alignment.
    
    """
    
    # Check for three prime length being longer than the primer_hit, correct to 
    # length of primer if so
    if tp_len > len(primer_hit):
        tp_len = len(primer_hit)
    
    # Get slices of 3', non 3', and last base regions of the primer & target
    if primer.Name.split('_')[0].endswith('f'):
        primer_non_tp = primer_hit[:-tp_len]
        primer_tp = primer_hit[-tp_len:-1]
        primer_last_base = primer_hit[-1]
        target_non_tp = target_hit[:-tp_len]
        target_tp = target_hit[-tp_len:-1]
        target_last_base = target_hit[-1]
    elif primer.Name.split('_')[0].endswith('r'):
        primer_non_tp = primer_hit[tp_len:]
        primer_tp = primer_hit[1:tp_len]
        primer_last_base = primer_hit[0]
        target_non_tp = target_hit[tp_len:]
        target_tp = target_hit[1:tp_len]
        target_last_base = target_hit[0]
    else:
        raise ValueError,\
         "Primer name must end with 'f' or 'r' to indicate forward or reverse."
         
    # Count insertions and deletions due to gaps
    non_tp_gaps = primer_non_tp.count('-') + target_non_tp.count('-')
    tp_gaps = primer_tp.count('-') + target_tp.count('-') +\
     primer_last_base.count('-') + target_last_base.count('-')

    
    # Sum non three prime mismatches
    non_tp_mismatches = 0
    for i in range(len(target_non_tp)):
        # using the scoring function to check for
        # matches, but might want to just access the dict
        if sw_scorer(target_non_tp[i], primer_non_tp[i]) == -1 and \
         target_non_tp[i] != '-' and primer_non_tp[i] != '-': 
            non_tp_mismatches += 1
    
    # Sum three prime mismatches
    tp_mismatches = 0
    for i in range(len(target_tp)):
        # using the scoring function to check for
        # matches, but might want to just access the dict
        if sw_scorer(target_tp[i], primer_tp[i]) == -1 and \
         target_tp[i] != '-' and primer_tp[i] != '-': 
            tp_mismatches += 1
            
    # Check for last base mismatch
    last_base_mismatches = 0
    if sw_scorer(target_last_base, primer_last_base) == -1 and \
     target_last_base != '-' and primer_last_base != '-': 
        last_base_mismatches = 1
    
    # Calculated weighted score that's rounded to nearest whole number.
    weighted_score = (last_base_mm * last_base_mismatches +\
     tp_mm * tp_mismatches + non_tp_mm * non_tp_mismatches + tp_gap * tp_gaps +\
     non_tp_gap * non_tp_gaps)
            
    return weighted_score, non_tp_gaps, tp_gaps, non_tp_mismatches,\
     tp_mismatches, last_base_mismatches
     



#####
# End mismatch counting functions
#####
    
        

####
# Misc functions
####


def hits_seq_end(seq, 
                 hit_start,
                 primer_len):
    """ Test if primer abuts sequence end, returns True/False
    
    seq: Current fasta sequence being tested
    hit_start: Index of primer hit, will be 5' position for forward primer,
     3' position for reverse primer
    primer_len: length of primer """
    
    seq_len = len(seq)
    if hit_start == 0 or (hit_start+primer_len>=seq_len):
        hits_sequence_end = True
    else:
        hits_sequence_end = False
        
    return hits_sequence_end
    
    
    

def get_yaxis_max(all_data_sets,
                  max_bin=5,
                  bin_size=1):
    """ Returns largest single bin in list of lists
    
    The purpose of this function is to find the largest single bin so that
    all subplots in a graph can use this maximum value for the y-axis size.
    
    all_data_sets: list of lists containing primer hit data (3', non 3'
     mismatches, 3' and non 3' gaps, weighted score).
    max_bin: Upper limit that values are capped at for creating bins.
    bin_size: step size for bins.  Module is currently written to handle
     whole numbers, if fractional values are used, must be careful to 
     ensure that all possible bin values are covered to avoid strange results.
    """
    
    counts_all_max = []
    
    for data_set in all_data_sets:
        # Create bins
        counts, bins, rects = hist(data_set, bins=arange(0, max_bin, bin_size))
        counts_all_max.append(max(counts))
        
    return max(counts_all_max)
    
    
def get_primers(primers_data=None, 
                primer_name=None,
                primer_sequence=None):
    """ Gets primers from filepath or from single specified primer name/seq
    
     primers_data: If specified, open file object for primers data
     primer_name: single primer name to analyze
     primer_sequence: single primer sequence to analyze
     
     If only the primers_data is provided, all primers in the file will
     be read and appended to a list as PyCogent DNA.Sequence objects.  If
     a single primer name is provided along with the primers_data, but no
     primer_sequence, then the primers list will be populated by the single
     primer and its sequence in the provided primers_data (if not found an
     error will be raised).  If both a primer_name and primer_sequence are
     provided, only a single primer will be constructed from these, and any
     primers file data passed will be ignored.
     """
     
    # User must specify a primers filepath, or a primer_name and 
    # primer_sequence, error check for this.
    if not primers_data and not(primer_name and primer_sequence):
        raise ValueError,("Missing primer(s) data.  User must specify either "+\
         "a primers filepath, or a primer name and sequence.  See the -P, -p,"+\
         " and -s parameters.") 
    
    primers = []
            
    # Check for correct naming convention of single primer specified
    if primer_name:
        
        # Fix primer name if not in correct format (followed by lower case f or
        # r.  Leave other components unchanged.
        primer_name = correct_primer_name(primer_name)
        # Check primer name for proper 'r' or 'f' ending
        if not (primer_name.split('_')[0].endswith('f') or 
         primer_name.split('_')[0].endswith('r')):
            raise ValueError, ('Primer name %s ' % primer_name +'does not '+\
             'end with "f" or "r".  The initial alphanumeric name of the '+\
             'primer must be followed by "f" or "r".  Example: 22f_archaeal')
    
    # If both primer name and seq provided, return single DNA sequence object
    # for that primer
    if primer_name and primer_sequence:
        primers.append(DNA.makeSequence(primer_sequence, Name=primer_name))
        return primers
    
    
    # Parse out primers data from formatted primers file, returns list
    # of tuples with (primer name, primer seq)
    raw_primers = parse_formatted_primers_data(primers_data)
    # Test all primer names for proper suffix of 'f' or 'r'
    for p in raw_primers:
        if not(p[0].split('_')[0].endswith('f') or
         p[0].split('_')[0].endswith('r')):
            raise ValueError,('Primer %s ' % p[0] +'does not end '+\
             'with "f" or "r".  The initial alphanumeric name of the '+\
             'primer must be followed by "f" or "r".  Example: 22f_archaeal')
    
    # If primer_name provided, return single DNA.Sequence object with that
    # particular primer name and sequence from the primers file
    if primer_name:
        # Search raw_primers for primer name that matches one provided
        for p in raw_primers:
            if p[0] == primer_name:
                primers.append(DNA.makeSequence(p[1], Name=primer_name))
                return primers
        # If primer name not found, raise value error
        raise ValueError,('Primer %s ' % primer_name +'not found in input '+\
         'primers file, please add to primers file or specify sequence with '+\
         'the -s parameter.')
         
    # If not using a single primer, build all primers in input primers file
    for p in raw_primers:
        primers.append(DNA.makeSequence(p[1], p[0]))
        
    # Raise error if nothing built from input file
    if not(primers):
        raise ValueError,('No primers were read from input primers file, '+\
         'please check file format.')
    
    return primers
                
        
####
# Main program loops
####

def get_hits_data(primer, 
                  primer_id,
                  fasta_fp,
                  tp_len,
                  last_base_mm,
                  tp_mm,
                  non_tp_mm,
                  tp_gap,
                  non_tp_gap):
    """ Finds mismatches, gaps, scores for primer/seqs sets
    
    Returns a list of lines of hits data for writing to the output hits file,
    and a list of lists containing the mismatches, gaps, and weighted scores
    for writing a histogram file.
    
    primer: current primer (DNA.Sequence object)
    primer_ids: current primer name
    fasta_fp: current open fasta filepath object to test primers against
    seq_collection: tuple of (collection_id, seq_collection), with id based upon
     root name of fasta file, collection is degapped SequenceCollection object
    tp_len: three prime length
    last_base_mm: penalty for last base mismatch
    tp_mm: three prime mismatch penalty
    non_tp_mm: non three prime mismatch penalty
    tp_gap: penalty for three prime gaps
    non_tp_gap: penalty for non three prime gaps
    """
    
    
    
    
    # Contains header, parameters, comments for the output hits file
    hits_lines = ["# Primer: %s 5'-%s-3'" % (primer.Name, primer),
     '# Input fasta file: %s' % basename(fasta_fp.name),
     '# Parameters',
     '# 3\' length: %d' % tp_len,
     '# non 3\' mismatch penalty: %1.2f per mismatch' % non_tp_mm,
     '# 3\' mismatch penalty: %1.2f per mismatch' % tp_mm,
     '# last base mismatch penalty: %1.2f' % last_base_mm,
     '# non 3\' gap penalty: %1.2f per gap' % non_tp_gap,
     '# 3\' gap penalty: %1.2f per gap' % tp_gap,
     '# Note - seq hit and primer hit are the best local pairwise alignment '+\
     'results for a given sequence and primer pair.  A gap in seq hit '+\
     'represents a '+\
     'deletion in the sequence, whereas a gap in the primer hit signifies '+\
     'an insertion in the target sequence.\n#\n'
     '# seq ID, seq hit, primer hit, hit start position, non 3\' mismatches, '+\
     '3\' mismatches (except last base), last base mismatch, '+\
     'non 3\' gaps, 3\' gaps, overall weighted score, '+\
     'hits sequence end ']
     
     
    # Calculate range of GC content, accounting for degeneracies
    min_gc = sum([primer.count(c) for c in 'GCS']) / len(primer)
    max_gc = sum([primer.count(c) for c in 'GCSNRYKMBDHV']) / len(primer)
    
    
    # Put together strings for text in output summary graphs
    degen_gc_content = '%s; Degeneracy: %d; GC content %.2f - %.2f'%\
     (primer_id, primer.possibilities(), min_gc, max_gc)
    primer_title = '\n5\'-%s-3\'' % str(primer)
    seq_collection_title = '\nSequences tested: ' + basename(fasta_fp.name)
    figure_title = degen_gc_content + primer_title + seq_collection_title
    
    # Weighted score strings for the bottom of the histogram, following
    # weighted score results.
    tp_len_title = '3\' length: %d nucleotides' % tp_len
    weighted_score_info = "\nWeighted score = non-3' mismatches * "+\
     "%1.2f + 3' mismatches * %1.2f + non 3' gaps * %1.2f + 3\' gaps * %1.2f" %\
     (non_tp_mm, tp_mm, non_tp_gap, tp_gap)
    last_base_info = '\nAn additional %1.2f penalty is assigned if the ' %\
     last_base_mm + 'final 3\' base mismatches'
    rounded_clause = '\nWeighted score is rounded to the nearest whole '+\
     'number in this graphical display'
    weighted_score_subtext = tp_len_title + weighted_score_info +\
     last_base_info + rounded_clause
    
    
    # Set upper limit for purpose of displaying data on histograms
    max_mm = 5
    max_gaps = 5
    max_weighted_score = 5.0
    
    non_tp_mm_data = []
    tp_mm_data = []
    non_tp_gap_data = []
    tp_gap_data = []
    weighted_score_data = []
    last_base_mm_data = []
    
    
    # get primer length to test for hitting sequence end
    primer_len = len(primer)
    primer_seq = primer_to_match_query(primer)
    
    for label, seq in MinimalFastaParser(fasta_fp):
        primer_hit, target_hit, hit_start = \
         local_align_primer_seq(primer_seq, seq)
        # Get score, numbers of gaps/mismatches
        weighted_score, non_tp_gaps, tp_gaps, non_tp_mismatches,\
         tp_mismatches, last_base_mismatches = score_primer(primer, primer_hit,
         target_hit, tp_len, last_base_mm,
         tp_mm, non_tp_mm, tp_gap, non_tp_gap)
        
        # Append data to lists for generating histograms
        # Max value appended to this list capped for purposes of readability
        # in the output histogram
        if non_tp_mismatches <= max_mm:
            non_tp_mm_data.append(non_tp_mismatches)
        else:
            non_tp_mm_data.append(max_mm)
            
        if tp_mismatches <= max_mm:
            tp_mm_data.append(tp_mismatches)
        else:
            tp_mm_data.append(max_mm)
            
        if non_tp_gaps <= max_gaps:
            non_tp_gap_data.append(non_tp_gaps)
        else:
            non_tp_gap_data.append(max_gaps)
            
        if tp_gaps <= max_gaps:
            tp_gap_data.append(tp_gaps)
        else:
            tp_gap_data.append(max_gaps)
            
        if weighted_score <= max_weighted_score:
            weighted_score_data.append(float('%2.2f' % weighted_score))
        else:
            weighted_score_data.append(max_weighted_score)
            
        if last_base_mismatches:
            last_base_mm_data.append(1)
        else:
            last_base_mm_data.append(0)
         
        # Determine if primer hits sequence end
        # Difficult to use this in scoring, but can be parsed out if one wants
        # to determine if primer sequences were left in fasta sequences
        hits_sequence_end = hits_seq_end(seq, hit_start, primer_len)
        
        # Append hit info for output hits file data
        # Label is split to just contain fasta ID
        hits_lines.append(','.join(map(str,[label.split()[0], target_hit, 
                primer_hit, hit_start, non_tp_mismatches, tp_mismatches,
                bool(last_base_mismatches), non_tp_gaps, tp_gaps,
                weighted_score, hits_sequence_end])))
                
    
    # Make list of all histogram data lists so only one data item being
    # passed around
    hist_data = [non_tp_mm_data, tp_mm_data, non_tp_gap_data, tp_gap_data,
     weighted_score_data, last_base_mm_data, figure_title, 
     weighted_score_subtext]
    
    
    
    return hits_lines, hist_data
        

        
def generate_hits_file_and_histogram(\
         primers,
         primer_ids,
         fasta_filepaths,
         max_mismatches = 4, 
         output_dir = ".", 
         verbose = False,
         tp_len = 5,
         last_base_mm = 3,
         tp_mm = 1,
         non_tp_mm = 0.4,
         tp_gap = 3,
         non_tp_gap = 1):
    """ Iterates through primers, test against input fasta sequences
    
    primers: list of primers (DNA.Sequence objects)
    primer_ids: list of primer names
    fasta_filepaths: list of fasta filepaths to test primers against
    max_mismatches: Setting to cap max mismatches in histogram output
    output_dir: Directory where hits files, summary graphs will be written
    verbose: enables printing to stdout of current primer being analyzed
    tp_len: three prime length
    last_base_mm: penalty for last base mismatch
    tp_mm: three prime mismatch penalty
    non_tp_mm: non three prime mismatch penalty
    tp_gap: penalty for three prime gaps
    non_tp_gap: penalty for non three prime gaps """

    
    for i in range(len(primers)):
        primer = primers[i]
        primer_id = primer_ids[i]
        if verbose:
            print "Starting %s" % primer_id
        for fasta_filepath in fasta_filepaths:
            
            fasta_fp = open(fasta_filepath, "U")
            
            # Get hits data and histogram data for writing the hits file and
            # histogram
            hits_data, hist_data = get_hits_data(primer, primer_id,
             fasta_fp, tp_len, last_base_mm,
             tp_mm, non_tp_mm, tp_gap, non_tp_gap)
                        
            # Generate output filepaths based on seq collection and primer name
            graph_filepath, hits_filepath = get_outf_paths(output_dir, primer,
             fasta_filepath)
            
            # Write lines of data from hits data to output hits filepath
            hits_f = open(hits_filepath, 'w')
            hits_f.write('\n'.join(hits_data))
            hits_f.close()
            
            fasta_fp.close()
            
            # write histogram
            write_primer_histogram(hist_data, graph_filepath)

    


def analyze_primers(fasta_fps, 
                    verbose = False, 
                    output_dir = ".", 
                    primers_filepath = None, 
                    primer_name = None, 
                    primer_sequence = None, 
                    tp_len = 5, 
                    last_base_mm = 3, 
                    tp_mm = 1, 
                    non_tp_mm = 0.4, 
                    tp_gap = 3, 
                    non_tp_gap = 1):
    """ Main function for primer analysis
    
    fasta_fps: fasta filepaths(s) to test the primers against.  For each fasta
     file tested, there will be a separate hits file and coverage graph
     generated
    verbose: enables printing of current primer being analyzed
    output_dir: Directory where hits files, summary graphs will be written
    primers_filepath: Path to file containing input primer names, seqs
    primer_name: single primer name to analyze
    primer_sequence: single primer sequence to analyze
    tp_len: three prime length
    last_base_mm: penalty for last base mismatch
    tp_mm: three prime mismatch penalty
    non_tp_mm: non three prime mismatch penalty
    tp_gap: penalty for three prime gaps
    non_tp_gap: penalty for non three prime gaps """
    # tp means 'three prime', mm 'mismatch'
    
    
    if primers_filepath:
        primers_data = open(primers_filepath, "U")
    else:
        primers_data = None
    
    # Build primers
    primers = get_primers(primers_data, primer_name, primer_sequence)
    
    # Test fasta filepaths, split into list of filepaths 
    fasta_filepaths = get_fasta_filepaths(fasta_fps)
    
    
    # Generate hits file 
    generate_hits_file_and_histogram(\
         primers,[p.Name for p in primers], fasta_filepaths,\
         max_mismatches=4, output_dir=output_dir, verbose = verbose,\
         tp_len=tp_len, last_base_mm=last_base_mm, tp_mm=tp_mm,\
         non_tp_mm=non_tp_mm, tp_gap=tp_gap, non_tp_gap=non_tp_gap)

    

    




