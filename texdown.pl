#!/usr/bin/perl                # <= Adapt if needed
###################################################
#
# texdown.pl
# 
# Convert a Scrivener Document into a LaTeX file.
# 
# This is not really a converter, it rater does a
# "compilation" - in Scrivener speak - from content
# that is in a Scrivener project into a LaTeX
# document.
# 
# It also does some conversion of some markup into
# LaTeX commands.
# 
# The motivation for starting this little project
# was that Scrivener is so unbelievably slow when
# compiling.
# 
# The other motivation was that scrivener always
# uses rtf documents, which are just not fit for
# git versioning really.
# 
# Optionally, it can also just convert plain
# text files that are marked up - in this case,
# just give actual file names instead of Scrivener
# directories as parameters.
# 
###################################################
# (c) Matthias Nott, SAP. Licensed under WTFPL.
###################################################

###################################################
#
# About the documentation:
# 
# Created like
# 
# pod2markdown.pl <texdown.pl >README.md
# 
# Using the excellent podmarkdwon by Randy Stauner. 
#
###################################################

my $pod2markdown="pod2markdown.pl"; # assumed to be in $PATH

###################################################
#
# Sample Usage:
# 
# Call the program with no parameters to get the
# help function. Alternatively, use the -man
# parameter to have the help shown as manual.
# 
# Configuration:
# 
# For adding your own regular expression, look at
# the %parser definition further down this file.
#
###################################################

use strict;
use warnings;
 
binmode STDOUT, ":utf8";
use utf8;
use Config::Simple;
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use RTF::TEXT::Converter;
use XML::LibXML;
use Tie::IxHash;

my $cfg;
my $config;
my @projects = ();
my $dontparse;
my $debug;
my $man = 0;
my $help = 0;
my $documentation = 0;
my $list          = 0;
my $all           = 0;

my $itemlevel   = 0;  # for itemizes: level; 0, 1 or 2
my $currentitem = ""; # current bullet kind: "", "m" or "t"


#
# Parse command line
#
GetOptions ('c|cfg:s'           => \$cfg,           # if set, texdown will drive itself by cfg
            'p|projects:s{,}'   => \@projects,      # if scriv, document folder(s) to start with
            'n|no|nothing'      => \$dontparse,     # if set, dont parse md
            'v|d|debug|verbose' => \$debug,         # if set, print some debug info
            'help|?|h'          => \$help,          # if set, print help screen
            'man'               => \$man,           # if set, print manual
            'documentation'     => \$documentation, # if set, recreate the documentation
            'l|list'            => \$list,          # if set, only list section ids and names
            'a|all'             => \$all,           # if set, not only list items "in compilation"
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


###################################################
#
# Set up the Markdown Parser for LaTeX
# 
# You can add your own regular expressions here.
# 
###################################################

my %parser;
tie %parser, 'Tie::IxHash';

%parser = (
  #
  # Remove some crap from the rtf2txt conversion
  #
  'HelveticaNeue;'  => '""',        # This keeps reappearing...

  # Remove Comments that Scrivener needs to ignore plain LaTeX.
  # Actually we could just not anymore write even those comments
  # into Scrivener; yet in the Scrivenings view, it may be nicer
  # not to see plain LaTeX code. 
  #
  '<!--' => '" "',
  '-->' => '" "',

  #
  # Quotes (the order is important!)
  #
  '"(\s)'  => '"\'\'$1"',           # end of double quote
  '(\s)\'' => '"$1`"',              # start of single quote
  '(\s)"'  => '"$1``"',             # start of double quote
  '^\''    => '"`"',                # single quote at line start
  '^"'     => '"``"',               # double quote at line start
  '"$'     => '"\'\'"',             # double quote at line end
  '``\''   => '"``\thinspace`"',    # start of triple quote
  '\'\'\'' => '"\'\thinspace\'\'"', # end of triple quote


  #
  # Convert Section headings etc. and add labels
  # 
  # Labels are the section headers, with spaces converted to dashes
  # 
  # So for example, if you do
  # 
  # ### Methodology and Constraints
  # 
  # You get
  # 
  # \section{Methodology and Constraints}\label{Methodology-and-Constraints}
  # 
  # So that later you can refer to it like so:
  # 
  # [r^ Methodology and Constraints]
  # 
  # Which will be converted to (see further below)
  # 
  # \ref{Methodology-and-Constraints}
  # 
  # 
  '^# (.*?)$' => '"\part{$1}\label{".nomarkdown(nospace($1))."}"',
  '^## (.*?)$' => '"\chapter{$1}\label{".nomarkdown(nospace($1))."}"',
  '^### (.*?)$' => '"\section{$1}\label{".nomarkdown(nospace($1))."}"',
  '^#### (.*?)$' => '"\subsection{$1}\label{".nomarkdown(nospace($1))."}"',
  '^##### (.*?)$' => '"\subsubsection{$1}\label{".nomarkdown(nospace($1))."}"',
  '^###### (.*?)$' => '"\paragraph{$1}\label{".nomarkdown(nospace($1))."}"',
  '^####### (.*?)$' => '"\subparagraph{$1}\label{".nomarkdown(nospace($1))."}"',

  '^#\* (.*?)$' => '"\part*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^##\* (.*?)$' => '"\chapter*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^###\* (.*?)$' => '"\section*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^####\* (.*?)$' => '"\subsection*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^#####\* (.*?)$' => '"\subsubsection*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^######\* (.*?)$' => '"\paragraph*{$1}\label{".nomarkdown(nospace($1))."}"',  
  '^#######\* (.*?)$' => '"\subparagraph*{$1}\label{".nomarkdown(nospace($1))."}"',  


  '^#\[([^]]*)\] (.*?)$' => '"\part[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^##\[([^]]*)\] (.*?)$' => '"\chapter[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^###\[([^]]*)\] (.*?)$' => '"\section[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^####\[([^]]*)\] (.*?)$' => '"\subsection[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^#####\[([^]]*)\] (.*?)$' => '"\subsubsection[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^######\[([^]]*)\] (.*?)$' => '"\paragraph[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^#######\[([^]]*)\] (.*?)$' => '"\subparagraph[$1]{$2}\label{".nomarkdown(nospace($2))."}"',

  #
  # Footnotes
  # 
  # __xyz__ => \footnote{xyz}
  # 
  #'\|\^\s*([^|]*)\|' => '"\footnote{$1}"',
  #'\^\^\s*([^^]*)\^\^' => '"\footnote{$1}"',
  '__\s*([^_]*)__' => '"\footnote{$1}"',

  #
  # Citations
  # 
  # We support
  # 
  # [#], [p#] =>  citep
  # [a#]      =>  citeauthor
  # [c#]      =>  cite
  # [t#]      =>  citet
  # [y#]      =>  citeyear
  # [yp#]     =>  (citeyear)
  # 
  # All of them take an optional () in front of the []
  # and will parse this in as for the pages section. 
  # So for example:
  # 
  # (20-30)[#xyz] => \citep[20-30]{xyz}
  # 
  # Alternativel, for "ibd." citations, you can use
  # the shorthand "i", so like [i#], [yi#], etc:
  # 
  # [ypi#xyz]     => (\citeyear[ibd.]{xyz})
  # 

  #  
  # (xyz)[#auth,...]    => \citep[xyz]{auth,...}
  # [#auth,...]         => \citep{auth,...}
  # (xyz)[p#auth,...]   => \citep[xyz]{auth,...}
  # [p#auth,...]        => \citep{auth,...}
  # 
  '\(([^()]*)\)\[#\s*([^]]*)\]' => '"\citep[$1]{$2}"',
  '\[i#\s*([^]]*)\]' => '"\citep[ibd.]{$1}"',
  '\[#\s*([^]]*)\]' => '"\citep{$1}"',
  '\(([^()]*)\)\[p#\s*([^]]*)\]' => '"\citep[$1]{$2}"',
  '\[pi#\s*([^]]*)\]' => '"\citep[ibd.]{$1}"',
  '\[p#\s*([^]]*)\]' => '"\citep{$1}"',
  #
  # (xyz)[a#auth,...]   => \citeauthor[xyz]{auth,...}
  # [a#auth,...]        => \citeauthor{auth,...}
  # 
  '\(([^()]*)\)\[a#\s*([^]]*)\]' => '"\citeauthor[$1]{$2}"',
  '\[ai#\s*([^]]*)\]' => '"\citeauthor[ibd.]{$1}"',
  '\[a#\s*([^]]*)\]' => '"\citeauthor{$1}"',
  #
  # (xyz)[c#auth,...]   => \cite[xyz]{auth,...}
  # [c#auth,...]        => \cite{auth,...}
  # 
  '\(([^()]*)\)\[c#\s*([^]]*)\]' => '"\cite[$1]{$2}"',
  '\[ci#\s*([^]]*)\]' => '"\cite[ibd.]{$1}"',
  '\[c#\s*([^]]*)\]' => '"\cite{$1}"',
  #
  # (xyz)[t#auth,...]   => \citet[xyz]{auth,...}
  # [t#auth,...]        => \citet{auth,...}
  # 
  '\(([^()]*)\)\[t#\s*([^]]*)\]' => '"\citet[$1]{$2}"',
  '\[ti#\s*([^]]*)\]' => '"\citet[ibd.]{$1}"',
  '\[t#\s*([^]]*)\]' => '"\citet{$1}"',
  #
  # (xyz)[y#auth,...]   => \citeyear[xyz]{auth,...}
  # [y#auth,...]        => \citeyear{auth,...}
  #
  '\(([^()]*)\)\[y#\s*([^]]*)\]' => '"\citeyear[$1]{$2}"',
  '\[yi#\s*([^]]*)\]' => '"\citeyear[ibd.]{$1}"',
  '\[y#\s*([^]]*)\]' => '"\citeyear{$1}"',
  #
  # (xyz)[yp#auth,...]   => (\citeyear[xyz]{auth,...})
  # [yp#auth,...]        => (\citeyear{auth,...})
  #
  '\(([^()]*)\)\[yp#\s*([^]]*)\]' => '"(\citeyear[$1]{$2})"',
  '\[ypi#\s*([^]]*)\]' => '"(\citeyear[ibd.]{$1})"',
  '\[yp#\s*([^]]*)\]' => '"(\citeyear{$1})"',

  #
  # Labels
  # 
  # Spaces, except leading spaces, are converted to dashes
  # 
  # [l# abc] => \label{abc}
  #
  '\[l#\s*([^]]*)\]' => '"\label{".nospace($1)."}"',

  #
  # References
  # 
  # If the reference contains spaces, they are converted to dashes
  # except for leading spaces, which are removed
  # 
  # [r# abc]  => \ref{abc}
  # [vr# abc] => \vref{abc}
  # [pr# abc] => \pageref{abc}
  # [er# abc] => \eqref{abc}
  #
  '\[r#\s*([^]]*)\]' => '"\ref{".nospace($1)."}"',
  '\[pr#\s*([^]]*)\]' => '"\pageref{".nospace($1)."}"',
  '\[vr#\s*([^]]*)\]' => '"\vref{".nospace($1)."}"',
  '\[er#\s*([^]]*)\]' => '"\eqref{".nospace($1)."}"',

  #
  # Emphasis
  # 
  # **xyz** => \emph{xyz}
  # 
  #'\*\*\*\s*([^*\s]*)\s*\*\*\*' => '"\emph{$1}"',
  '\*\*([^*]*)\*\*' => '"\emph{$1}"',

);


#
# Shortcut for myself to recreate the documentation
# without having to remember how it was done.
# 
if ($documentation) {
  system("$pod2markdown <texdown.pl >README.md");
  exit 0;
}


#
# If we have a configuration file set, we use that
# as to drive ourselves, i.e. we assume we'll find
# more information in there as to which projects to
# parse, in which order, and to which destination,
# and what to do with that destination.
# 
# This essentially creates a wrapper around texdown.
# 
if ($cfg) {
  runFromCfg (@ARGV);
} else {
  #
  # Decide which processing ot use: STDIN or files
  #
  if (-t STDIN) {
    if (@ARGV > 0) {
      runOnFiles (@ARGV);
    } else {
      pod2usage(2);
    }
  } else {
    runAsFilter();
  }
}


#
# nospace
#
# Simple function to remove Spaces from a String
# 
# This function is called from some regular expressions
# that e.g. want to translate a "Section Header" into
# a label like "Section-Header".
# 
# Inside a regular expression it is called, on the
# replace side, like so:
# 
# '"...".nospace($1)."..."'
# 
# It is important that you get the variable passed to it
# using shift, not relying on $_; otherwise you'll get
# the whole match string, not just the group you're
# looking for.
# 
# $str   : The string to parse
# returns: The parsed string with spaces replaced by -
# 
sub nospace {
  my $str = shift;
  $str =~ s/ /-/g;

  return $str;
}


#
# Drop any Markdown (for auto generated header labels)
# 
sub nomarkdown {
  my $str = shift;
  $str =~ s/\[[^\]]*\]//g;

  return $str;
}


#
# parse
#
# Regular Expression parser usign the %parser
# Parse table
# 
# $input : Text content to parse
# returns: The parsed content
# 
sub parse {
  my $input = shift;
  my $output;

  for (split /^/, $input) {
    chomp;
    my $line = $_;

    my $content = $line;
    my $comment = "";

    #
    # Really dirty hack to parse comments: we have
    # to differentiate between actual comments, in
    # which case we want to not parse anything until
    # the end of the line, and some arbitrary percent
    # sign somewhere on the line, which, because of
    # how LaTeX works, would logically have been
    # escaped with a leading \. If we did have a
    # real comment, we parse only the part up to
    # the comment.
    # 
    # Otherwise, we need to parse the whole line.
    # To do so, we first replace escaped comments
    # by some string that we hope does not exist
    # on the line, leaving any eventually true
    # comments alone.
    # 
    # Then we split at those true comments, if any,
    # and parse only the first half.
    #
    $line =~ s/\\%/!NOCOMMENT!/g;

    if ($line =~ m/(.*?)%(.*)$/) {
      $content = $1;
      $comment = "%".$2;
    }

    while (my ($search, $replace) = each(%parser)) {
      $replace =~ s/\\/\\\\/g;
      $content =~ s/$search/$replace/eeg;
    }

    $content =~ s/!NOCOMMENT!/\%/g;
    $comment =~ s/!NOCOMMENT!/\%/g;

    #
    # Test for itemizes
    # 
    $content = itemize($content);

    #
    # Reconcatenate content and comments (if any)
    #
    $output .= "$content$comment\n";
  }
  return $output;
}


#
# itemize
#
# Working with itemizes
# 
# TODO: For the moment we support only one
#       level, as Scrivener doesn't really
#       support more anyway (if we convert
#       rtf to txt, only one level is there
#       to be identified):
#       
#       If we export from Scrivener, we can
#       have only two levels of itemizes:
#       
#       Case a):
#       
#       \t         => Level 1
#       &middot;\t => Level 2
#       
#       Case b):
#       
#       &middot;\t => Level 1
#       \t         => Level 2
#       
#       Any further indentation from the point
#       of view of Scrivener will not be 
#       reflected in the converted text file.
#       Hence, we have at best two levels of
#       indentation.
#       
#       For simplification, let's name a line
#       starting with \t "t", one with "&middot;\t"
#       as "m", and otherwise "" - which will be
#       in $currentitem.
#       
#       $itemlevel will be 0, 1 or 2.
#     
#       So we have this cases for what we found
#       at the beginning of the line:
#       
#        Case Found   $itemlevel  $currentitem Action
#       ---------------------------------------------
#         1   ""      1 or 2      m or t        E1
#         2   "\t"    0           ""            E2
#         3   "\t"    1 or 2      t             E3
#         4   "\t"    1           m             E4
#         5   "\t"    2           m             E5
#         6   "m"     0           ""            E2
#         7   "m"     1 or 2      m             E3
#         8   "m"     1           t             E4
#         9   "m"     2           t             E5
#       
#       
#       E1: * End all itemizes
#           - End as many itemizes as we had (1 or 2)
#             as per $itemlevel by adding \end{itemize}s
#           - $itemlevel=0;
#           - $currentitem="";
#           
#       E2: * Start level 1
#           - Prefix line with \begin{itemize}\item 
#           - $itemlevel=1;
#           - $currentitem = (what was found);
#           
#       E3: * Continue on same level
#           - Prefix line with \item 
#       
#       E4: * Start level 2
#           - Prefix line with \begin{itemize}\item 
#           - $itemlevel=2;
#           - $currentitem = (what was found);
#      
#       E5: * End level 2
#           - Prefix line with \end{itemize\n\item
#           - $itemlevel=1;
#           - $currentitem = (what was found);
#           
#       In all cases, we need to replace a given
#       "&middot;" by "\t" on level 1, or  "\t\t"
#       on level 2, as otherwise LaTeX will not
#       compile. Similarly, on level 2, we will
#       replace "\t" by "\t\t". Maintaining the
#       indentation level is cosmetic only at this
#       point.
#       
#  Yes. I know. It is horrific. But it's working for now...
#  
# $line  : The line to parse for detecting itemizes
# returns: The parsed line, with optionally added itemize etc.
#       
sub itemize {
  my $line = shift;

  if (! ($line =~ /^[\t]+.*$/) && ! ($line =~ /^[\t]*\&middot;\t.*$/) && $currentitem ne "") {
    # 1 => E1
    if ($itemlevel == 2) {
      $line = "\\end{itemize}\n\\end{itemize}\n\n" . $line;
    } elsif ($itemlevel == 1) {
      $line = "\\end{itemize}\n\n" . $line; 
    }
    $currentitem = "";
    $itemlevel = 0;
    return $line;
  } elsif ($line =~ /^[\t]+(.*)$/) {
    my $content = $1;
    if ($itemlevel == 0 && $currentitem eq "") {
      # 2 => E2
      $content = "\\begin{itemize}\n\t\\item $content";
      $itemlevel = 1;
      $currentitem = "t";
    } elsif($itemlevel > 0 && $currentitem eq "t") {
      # 3 => E3
      if($itemlevel == 1) {
        $content = "\t\\item $content";  
      } else {
        $content = "\t\t\\item $content";
      }
    } elsif($itemlevel == 1 && $currentitem eq "m") {
      # 4 => E4
      $content = "\\begin{itemize}\n\t\t\\item $content";
      $itemlevel = 2;
      $currentitem = "t";
    } elsif($itemlevel == 2 && $currentitem eq "m") {
      # 5 => E5
      $content = "\\end{itemize}\n\t\\item $content";
      $itemlevel = 1;
      $currentitem = "t";
    }
    $line = $content;
  } elsif ($line =~ /^[\t]*\&middot;\t(.*)$/) {
    my $content = $1;
    if ($itemlevel == 0 && $currentitem eq "") {
      # 6 => E2
      $content = "\\begin{itemize}\n\t\\item $content";
      $itemlevel = 1;
      $currentitem = "m";
    } elsif($itemlevel > 0 && $currentitem eq "m") {
      # 7 => E3
      if($itemlevel == 1) {
        $content = "\t\\item $content";  
      } else {
        $content = "\t\t\\item $content";
      }
    } elsif($itemlevel == 1 && $currentitem eq "t") {
      # 8 => E4
      $content = "\\begin{itemize}\n\t\t\\item $content";
      $itemlevel = 2;
      $currentitem = "m";
    } elsif($itemlevel == 2 && $currentitem eq "t") {
      # 9 => E5
      $content = "\\end{itemize}\n\t\\item $content";
      $itemlevel = 1;
      $currentitem = "m";
    }
    $line = $content;
  }

  return $line;
}


#
# cfg
# 
# Get some configuration variable value. The configuration
# file can hold scope sections such as
# 
#   [GLOBAL]
#   var1=val1
#   var3=val3
#   
#   [xyz]
#   var1=val2
#   var4=val4
#   
# In the above case, if we had asked for the value of var1 in
# the xyz scope, we would get val2; if we had asked for the
# value of var4 in the xyz scope, we would default to val3, etc.
# 
# $scope : The variable scope to get the variable from
# $var   : The variable name
# returns: The variable value from it's scope, if available, or
#          from GLOBAL scope, if available. Else an empty string.
#          
sub cfg {
  my ($scope, $var) = (@_);

  if(!$config) {
    return "";
  }

  my $val = $config->param($scope.".".$var);

  if(!$val) {
    $val = $config->param("GLOBAL.".$var);
  }

  if(!$val) {
    return "";
  }

  return $val;
}


#
# runFromCfg
# 
# Run from a configuration file
# 
sub runFromCfg {
  my ($dir, $file) = (@_);

  if (! -f $cfg) {
    pod2usage({ -message => "\nConfiguration file $cfg not found\n" ,
                -exitval => 2,
              });
  }

  #
  # If we did not specify a project, let's attempt to
  # resolve it.
  # 
  if (@projects == 0) {
    my ($d, $f, $p) = resolveFiles("$dir");

    $projects[0] = $p;
  }

  #
  # Capture current project and empty
  # out $projects - we are going to
  # read the projects from the configuration
  # file now.
  # 
  my @back = @projects; 
  @projects=();

  #
  # If we had been given a configuration file, make sure
  # we also have got a scrivx file.
  # 
  if (!$file) {
    ($dir, $file) = resolveFiles("$dir");
  }

  foreach my $curproj (@back) {
    #
    # Initialize the Configuration File
    # 
    $config = new Config::Simple($cfg);

    my $pr = cfg($curproj, "p");

    if (ref($pr) eq 'ARRAY') {
      @projects = @$pr;
    } else {
      $projects[0] = $pr;
    }

    parseScrivener($dir, $file);
  }

  #
  # Restore the projects
  # 
  @projects = @back;
}


#
# resolveFiles
# 
# Resolves the location and name of a file. For Scrivener,
# its content for a project like Dissertation is held in a
# directory Dissertation.scriv, which contains, among other
# things, an XML file Dissertation.scrivx. This function
# will resolve the location of the Dissertation.scriv
# directory, and return its directory, file/directory name,
# as well as its base name (in this case: Dissertation),
# for further processing.
# 
# $_ : Some file name or location to resolve.
# 
# returns:
#   $dir    : The Directory of the File, e.g., Dissertation.scriv
#   $file   : The Filename of the XML File, e.g., Dissertation.scriv/Dissertation.scrivx
#   $project: The Scrivener Directory base name, or an empty String
#
sub resolveFiles {
  my $arg = shift;
  if (-e "$arg" || -e "$arg.scriv") {
    my ($fname, $fpath, $fsuffix) = fileparse($arg, qr/\.[^.]*/);
    my $basename = basename($arg, qr/\.[^.]*/);
    my $dirname = dirname($arg);

    #
    # If we have an $fname, it can still be a directory,
    # because Scrivener saves its files in "files," which
    # are really directories. So we have to test some cases.
    # 
    if ($fname ne "") {
      if (-d "$fpath$fname.$fsuffix") {
        $fpath = "$fpath$fname$fsuffix";
      } elsif (-d "$fpath$fname.scriv") {
        $fsuffix = ".scriv";
        $fpath = "$fpath$fname$fsuffix";
      } else {
        $fpath = $_;
      }
    } else {
      if (-d "$fpath") {
        $fpath =~ s/(.*?\.scriv).*/$1/;
      }
    }

    my $found = $fpath;
    ($fname, $fpath, $fsuffix) = fileparse($fpath, qr/\.[^.]*/);

    if (-d "$found" && -e "$found/$fname.scrivx") {
      my $dir  = "$found";
      my $file = "$fpath$fname.scriv/$fname.scrivx";

      return ($dir, $file, $fname);
    } elsif (-f "$found") {
      my $dir  = "$fpath";
      my $file = "$found";

      return ($dir, $file, "");
    } 
  }
}


#
# runOnFiles
#
# Do the processing on files
# from the command line
# 
# arguments: The files to parse
#
sub runOnFiles {
  foreach (@ARGV) {
    if (-e "$_" || -e "$_.scriv") {
      my ($dir, $file, $project) = resolveFiles($_);

      if ($project ne "") {
        #
        # Scrivener
        # 

        #
        # Option 1:
        # 
        # - Indirect project definition by configuration file...
        # - ...but don't even say, which configuration file to use
        # - ...or even, which project to use from that file
        #
        # If we don't have a project, as a fallback, we default
        # to the $fname, and if we do have a $fname.cfg, and the
        # cfg option was not set on the command line, we 
        # default to it using the $fname as project to run.
        # 
        # This is invoked e.g. like so:
        # 
        # ./texdown.pl Dissertation -l -c
        # 
        # We are hence working on Dissertation.scriv, but we are
        # not even saying which project we want to run, and neither
        # are we saying which configuration file we want to use. We
        # just say that we want to use a configuration file. In this
        # case, the program will assume Dissertation.cfg as 
        # configuration file, and also, Dissertation as project.
        # 
        if (@projects == 0) {
          $projects[0] = $project;
            
          if (defined($cfg)) {
            if (-f "$dir/../$project.cfg") {
              $cfg = "$dir/../$project.cfg";
              runFromCfg($dir, $file);

              next;
            }
          }
        }


        #
        # Option 2:
        # 
        # - Indirect project definition by configuration file...
        # - ...but don't even say, which configuration file to use
        # - yet at least, we say which project(s) to use
        #
        # If we did have projects, and cfg set, but empty,
        # we still try to find a default configuration,
        # rather than running on the projects ourselves
        # 
        # This is invoked e.g. like so:
        # 
        # ./texdown.pl Dissertation -l -c -p roilr
        # 
        # We are hence working on the Dissertation.scriv,
        # and we are saying we want to use a configuration
        # file, without specifying its name. Hence the
        # program will attempt to use Dissertation.cfg.
        # We also said that we want to use a given project
        # that's defined in the configuration file, in this
        # case roilr.
        # 
        if (@projects > 0 && defined($cfg) && $cfg eq "") {
          if (-f "$dir/../$project.cfg") {
            $cfg = "$dir/../$project.cfg";
            runFromCfg($dir, $file);

            next;
          }
        }

        #
        # This is the standard case, invoked e.g. like so:
        # 
        # ./texdown.pl Dissertation -l -p /Trash
        # 
        # We are working on Dissertation.scriv, and we say we
        # want to use a project that's actually like this available
        # in that file (we can use absolute or relative names).
        # 
        parseScrivener ($dir, $file);
      } else {
        #
        # Plain Text
        # 
        parsePlain ($dir, $file);
      }
    }
  }  
}


#
# runAsFilter
#
# Do the processing on input
# piped via STDIN
#
sub runAsFilter {
  while (<STDIN>) {
    my $line = $_;
    $line = parse($line) unless $dontparse;  
    print $line;  
  }  
}


#
# parseScrivener
# 
# Parse a Scrivener Database
# 
# $dir      : The .scriv  directory to parse
# $file     : The .scrivx file to parse in that directory
#
sub parseScrivener {
  my ($dir, $file) = (@_);

  if ($debug) {
    print "% Scrivener Processing...\n";
    print "% Projects   : " . join( ', ', @projects ) . "\n";
    print "% Directory  : $dir\n";
    print "% File       : $file\n";
  }

  my $doc = XML::LibXML->load_xml(location => $file);

  #
  # Check whether we have an absolute or a relative location
  # 
  foreach my $project (@projects) {
    if ($project =~ "^/.*") {
      #
      # Absolute location
      #
      my $leaf = 0;
      my $path = "/ScrivenerProject/Binder";
      foreach my $location (split("/", $project)) {
        if ($location ne "") {
          my $subpath = '/BinderItem[Title/text() = "'."$location".'"]';
          my $parentNode = $doc->findnodes($path.$subpath);

          #
          # If the parentNode does not exist, e.g. because of a typo,
          # we don't follow it up.
          # 
          if (!$parentNode) {
            $path .= "$subpath/Children";
            last;
          }

          #
          # Cound the children to detect leaves
          # 
          my $childcount = $doc->findvalue("count($path$subpath/Children)");

          my $parentType = @$parentNode[0]->getAttribute("Type");

          if ($childcount == 0 || $parentType eq "Text") {
            $path .= '/BinderItem[Title/text() = "'."$location".'"]';
            $leaf = 1;
          } else {
            $path .= "$subpath/Children";
          }
        }
      }

      $path .= "/*" unless $leaf;

      foreach my $binderItem ($doc->findnodes($path)) {
        printNode($binderItem, "", 0, $dir);
      }
      
    } else {
      #
      # Relative location; /Children/* are being resolved by recursion
      # 
      foreach my $binderItem ($doc->findnodes('//BinderItem[Title/text() = "'."$project".'"]')) {
        printNode($binderItem, "", 0, $dir)
      }
    }
  }
}


#
# printNode
# 
# Recursive Function to conditionally print and dive into children
# 
# $parentItem: The starting point of the tree
# $path      : The path up to the $parentItem
# $level     : The level of recursion
# $dir       : The directory to retrieve rtf files from
# 
sub printNode {
  my ($parentItem, $path, $level, $dir) = (@_);

  my $parentTitle = "$path/" . $parentItem->findnodes('./Title')->to_literal;
  my $docId   = $parentItem->getAttribute("ID");
  my $docType = $parentItem->getAttribute("Type");
  my $docTitle = $parentItem->findnodes('./Title')->to_literal;
  my $includeInCompile = $parentItem->findnodes('./MetaData/IncludeInCompile')->to_literal;

  #
  # If we are restricting by the Scrivener metadata field
  # IncludeInCompile (which we do by default), then if a
  # given node has that field unchecked, we don't print
  # that node, and we don't dive into it's children.
  # 
  return if(!$all && $includeInCompile ne "Yes");

  #
  # If the current node is a text node, we have to print it
  # 
  if($docType eq "Text") {
    if ($list) {
      my $printline = sprintf("[%8d] %s", $docId, $parentTitle);

      print "$printline\n";
    } else {
      my $rtf = "$dir/Files/Docs/$docId.rtf";
    
      if (-e "$rtf") {
        my $line = "";
        if($debug) {
          $line = "\n\n<!--\n%\n%\n% ". $docId . " -> " . $docTitle . "\n%\n%\n-->\n";
        }
        $line .= rtf2txt("$dir/Files/Docs/$docId.rtf");
    
        $line = parse($line) unless $dontparse;  
        print $line . "\n";
      }
    }
  }

  #
  # If the current node has children, we need to call them (and let
  # them decide whether they want to process themselves)
  # 
  foreach my $binderItem ($parentItem->findnodes('./Children/*')) {
    printNode($binderItem, $parentTitle, ++$level, $dir);
  }
}


#
# parsePlain
#
# Parse a Plain TeXDown File
# 
# $dir      : The directory to look into
# $file     : The file to parse
#
sub parsePlain {
  my ($dir, $file) = (@_);
  if ($debug) {
    print "% Plain processing...\n";
    print "% dir  : $dir\n";
    print "% file : $file\n";
  }

  open my $info, $file or die "Could not open $file: $!";

  while (my $line  = <$info>) {
    $line = parse($line) unless $dontparse;  
    print $line;
  }
  close $info;
}


#
# rtf2txt
# 
# Convert a file from rtf to a txt string.
# 
# $file     : The file to convert
# 
sub rtf2txt {
	my $file = shift;
	my $result;
	my $self = new RTF::TEXT::Converter(output => \$result);
	$self->parse_stream($file);
	return $result;
}




__END__

=head1 NAME

TeXDown  -  Use Markdown with LaTeX, and particularly with Scrivener.

            The program was written for two reasons:

             - Markdown gives a more distraction-free writing
               experience compared to LaTeX, even for seasoned
               LaTeX users

             - Scrivener is unbelievably slow at exporting its
               content, even if only into plain text files.

             In other words, I wanted to have something that is much
             faster, and also that is more adapted to typical LaTeX
             commands that I use every day - so that I can structure
             my writings with Scrivener, focusing on the content,
             while at the same time having the full power of LaTeX
             available, immediately.

<<<<<<< HEAD
             To do so, TeXDown does several things:
=======
             To do so, B<TeXDown> does several things:
>>>>>>> dff9414a560b906a2482eaed04482a76d2b05a94

             Parsing LaTeX files that contain some Markdown into
             LaTeX files.

             Also, do the same on Scrivener databases, extracting
             the contained rtf files, converting them to plain
             text, and then parsing them.

             The program can run both as a script as well as a
             filter. If running as a script, it will take files
             from the command line plus in addition to its own
             command line parameters. If running as a filter, it
             will take the input piped to the program, in addition
             to its own command line parameters.

=head1 SYNOPSIS

./texdown.pl [options] [files ...]

Command line parameters can take any order on the command line.

 Options:

   General Options:

   -help            brief help message (alternatives: ?, -h)
   -man             full documentation (alternatives: -m)
   -v               verbose (alternatives: -d, -debug, -verbose)
   -n               do not actually parse Markdown into LaTeX
                    (alternative: -no, -nothing)

   Scrivener Options:

   -p               The scrivener object name(s) to start with.
                    (alternative: -project)
   -a               Only include all objects, not only those that
                    were marked as to be In Compilation.
                    (alternative: -all)
   -l               Only list the ids and section titles of what would
                    have been included (alternative: -list)
<<<<<<< HEAD
   -c               Use a configuration file to drive TeXDown.
=======
   -c               Use a configuration file to drive B<TeXDown>.
>>>>>>> dff9414a560b906a2482eaed04482a76d2b05a94
                    (alternative: -cfg)

   Other Options:

   -documentation   Recreate the README.md (needs pod2markdown)


=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-v>

Put LaTeX comments into the output with the name of the file that
has been parsed.

=item B<-n>

Don't actually parse the Markdown Code into LaTeX code.

=item B<-p>

The root object(s) in a Scrivener database within the processing
should start. If not given, and if yet running on a Scrivener
database, the script will assume the root object to have the
same name as the Scrivener database.

If you want to process multiple object trees, just use this
command line argument multiple times, or pass multiple arguments
to it. For example, you can use

  ./texdown.pl Dissertation -p FrontMatter Content BackMatter

or

  ./texdown.pl Dissertation -p FrontMatter -p Content -p BackMatter

Each object name can be either an actual name of an object,
so for example, if you have an object

  /Research/Literature/XYZ

with a whole lot of objects beneath, you can give "XYZ", and
you will get everything beneath XYZ, or you can give "Literature",
and get everything below that (for example, "XYZ"). If you have
more than one objects by that name, you will get trees for all of
them.

Or, assume you would run into some ambiguity, or you would recruit
your material from completely disjunct object trees, you can also
use absolute path names. So assume you have some folder that contains
your front matter and back matter for articles, and then you have
some literature folder somewhere, you can do this:

  ./texdown.pl Dissertation -p /LaTeX/Articles/FrontMatter /LaTeX/Articles/BackMatter Literature

As a side effect, if you want to print out the entire object hierarchy
of your scrivener database, you can do this:

  ./texdown.pl Dissertation -p / -l

This will also give you a clue about the associated RTF file names,
as the IDs that are listed correspond directly to the rtf file names
living in the Files/Docs subdirectory of the Scrivener folder.

=item B<-a>

Disrespect the Scrivener metadata field IncludeInCompilation, which
can be set from Scrivener. By default, we respect this metadata 
field. Since it can be set at every level, if
we detect it to be unset at level n in the document tree, we will
not follow down into the children of that tree, even if they have
it set. This allows us to easily exclude whole trees of content 
from the compilation - except if we chose to include all nodes
using the -a switch.

=item B<-l>

Rather than actually printing the parsed content, only print
the document IDs and titles that would have been included. 

Those document IDs correspond to RTF files which you would find 
in the Files/Docs subdirectory; hence this option might be useful
for you to understand which file corresponds to which Scrivener object.

=item B<-c>

Use a configuration file to drive B<TeXDown>. This essentially wraps
B<TeXDown> in itself. If you use -c, you can remove the need to specify
all your projects on the command line. Here is a sample configuration
file:

  ;
  ; TeXDown Configuration File
  ;
  [GLOBAL]
  
  [Dissertation]
  p=Dissertation
  
  [rd]
  ; Research Design
  p=/LaTeX/Article/Frontmatter, "Research Design", /LaTeX/Article/Backmatter
  
  [roilr]
  ; ROI - Literature Review
  p=/LaTeX/Article/Frontmatter, "ROI - Literature Review", /LaTeX/Article/Backmatter

Let's assume we have saved this file as Dissertation.cfg, into
the same directory where we are also having our Scrivener directory
Dissertation.scriv. The above file works as follows: You can specify
some variables with "scopes" (like, "rd"), and this will serve as an
indirection to define which projects really to use.

So for example, if you call the program like so (I'm using -l in the
subsequent examples because listing the assets rather than converting
them will make it clearer for you what happens; at the end, you'd of
course remove the -l and pipe the output somewhere):

  ./texdown.pl Dissertation -l -c

you are not even saying which project or which configuration file to
use. So what B<TeXDown> will do is to assume that the configuration
file lives in the same directory that your Dissertation.scriv is in,
and is named Dissertation.cfg. It will also assume that you expect to
have a scope [Dissertation] within that file, and within that section,
you have a project definition like p=something.

If you are more specific, you can make a call like so:

  ./texdown.pl Dissertation -l -c -p roilr

In that case, you are still not specifying your configuration file, so
it will be treated as in the previous case. But you are saying that you
want to call the scope [roilr], in which case the project definition
is taken from that scope.

To be even more specific, you can explicitly say which configuration
file to use:

  ./texdown.pl Dissertation -l -c Dissertation.cfg

This is going to look for the Dissertation.cfg configuration file,
in some location (you can now give a complete path to it), and since
we yet forgot again, which project to actually use, it is going to
default to the Dissertation scope in that file.

Let's be really specific and also say, which project to use with
that configuration file:

  ./texdown.pl Dissertation -l -c Dissertation.cfg -p roilr

Of course, you can now be really crazy and run a number of projects
in a row:

  ./texdown.pl Dissertation -l -c -p roilr rd Dissertation

This will tell B<TeXDown>, again, to use Dissertation.cfg out of the
same directory where the referred to Dissertation.scriv lives, and to
then process the scopes roilr, rd, and Dissertation, in that order.

Of course, this somehow only makes sense if you can specify a different
output file, or intermediate processing, which I've not yet implemented.
But that's, at the end, once it is done, the what [GLOBAL] section will
be for: There we'll be able to specify e.g. the default LaTeX command
to process the output.


=item B<-documentation>

Use pod2markdown to recreate the documentation / README.md.
You need to configure your location of pod2markdown at the
top, if you want to do this (it's really an option for me,
only...)

=back


=head1 DESCRIPTION

=head2 INSTALLATION

Put the script somewhere and make it executable:

  cp texdown.pl ~/Desktop
  chmod 755 ~/Desktop/texdown.pl

(Desktop is probably not the best place to put it, but just to
make the point.) Also, make sure that you reference the right
version of Perl. At the beginning of the script, you see a
reference to /usr/bin/perl. Use, on the command line,
this command to find out where you actually have your Perl:

  which perl

Chances are, it is /usr/bin/perl

Next, there are a couple of packages that we use. If you start
the program and get a message like so:

  ./texdown.pl
  Can't locate RTF/TEXT/Converter.pm in @INC ....

Then this means you don't have the package RTF::TEXT::Converter
installed with your Perl installation. All the packages that are
on your system are listed at the top of B<texdown.pl>:

  use Getopt::Long;
  use Pod::Usage;
  use File::Basename;
  use Data::Dumper;
  use RTF::TEXT::Converter;
  use XML::LibXML;
  use Tie::IxHash;

So in the above case, where we were missing the RTF::TEXT::Converter,
you could do this:

  sudo cpan install RTF::TEXT::Converter

If you run into compilation problems, you might also first want to
upgrade your CPAN:

  sudo cpan -u

Like man cpan says about upgrading all modules, "Blindly doing this
can really break things, so keep a backup." In other words, for
B<TeXDown>, use the upgrade only if an install failed.


=head2 RUNNING as a FILTER

When running as a filter, B<TeXDown> will simply take the
content from STDIN and process it, taking any command line
parameters in addition. So for example, you could call it like
this:

  cat document.tex | ./texdown.pl -v

Or like this:

  ./texdown.pl -v <document.tex

The result will be on STDOUT, which means you can also pipe
the output into something else. For example a file:

  cat document.tex | ./texdown.pl > output.tex

And of course even to itself:

  cat document.tex | ./texdown.pl -n | ./texdown.pl -v

=head2 RUNNING as a SCRIPT

If running as a script, B<TeXDown> will take all parameters
that it does not understand as either command line parameters
or as values thereof, and try to detect whether these are files.
It will then process those files one after another, in the order
they are given on the command line. The output will again go to
STDOUT. So for example:

  ./textdown.pl -v test.tex test2.tex test3.tex >document.tex

In case you want to run B<TeXDown> against data that is in a
Scrivener database, you just pass the directory of that database
to it. So let's assume we've a Scrivener database B<Dissertation>
in the current directory.

This actually means that in reality, you would have a directory
B<Dissertation.scriv>, within which, specifically, you would find
a file B<Dissertation.scrivx>, along with some other directories.
This B<Dissertation.scrivx> is actually an XML file which we are
going to parse in order to locate the content that we want to
parse from LaTeX containing Markdown, to only LaTeX. The XML
file B<Dissertation.scrivx> basically contains the mapping
between the names of objects that you give in the Scrivener
Application, and the actual representations of those files on
the disk. Scrivener holds its files in a directory like
B<Dissertation.scriv/Files/Docs> with numbered filenames like
123.rtf.

So what B<TeXDown> will do is that it will first detect whether
a file given on the command line is actually a Scrivener database,
then it will try to locate the B<.scrivx> file within that, to 
then parse it in order to find out the root folder that you wanted
the processing to start at. It will then, one after another,
try to locate the related rtf files, convert them to plain text,
and then parse those.

So for example, assuming you have a Scrivener database B<Dissertation>
in the current directory, you can do this:

  ./texdown.pl Dissertation

Notice that we did not use the -projects parameter to specify the root
folder at which you want to start your processing. If this is the
case, B<TeXDown> will try to locate a folder that has the same
name as the database - in the above example, it will just use
B<Dissertation>.

So if you want to specify another root folder, you can do so:

  ./texdown.pl Dissertation -p Content

Piping the result into some file:

  ./texdown.pl Dissertation -p Content >document.tex

If you do not have the Scrivener project in your working directory,
you can chose any other way to call it, so like:

  ./texdown.pl ../my/writings/Dissertation.scriv/
  ./texdown.pl ../my/writings/Dissertation
  ./texdown.pl ~/Desktop/Dissertation.scriv

etc. The program is very graceful as to whether you actually specify
the extension B<.scriv>, whether you have absolute or relative paths,
or whether you have trailing slashes. It will just try to do the
right thing if you call it with something stupid like

  ./texdown.pl $(pwd)/./Dissertation.scriv/./././

You can also specify multiple Scrivener databases; at this moment,
they will all share the same root folder to start with.

=head1 CONFIGURATION

If you want to add your own parsers, have a look at the source code
of the file. It is pretty well documented.

=head1 LIMITATIONS

At this moment, B<TeXDown> works on single lines only. In other
words, we do not support tags that span multiple lines. We have just
added limited, and ugly, support for itemizes, which works sufficiently
well with Scrivener: Scrivener gives at best two levels of itemizes
anyway. For more complex ones, and enumerates, you still will need to
use plain LaTeX. We also don't support tables so far: I believe this
is strongly overrated, as real LaTeX users won't contend with simple
tables anyhow.

Practically, this means that you will e.g. have to have your
footnotes in one line, like __This is a footnote__ - of course
you can at any time also use actual LaTeX commands, and if you
do not want to see them in Scrivener, you can just escape them
using <!-- \footnote{This is another footnote.} -->

=head1 SYNTAX

The Markdown code that this program uses is neither
MultiMarkDown (mmd) nor Pandoc compatible, since these
were too limited as to their support of LaTeX.

Here are the options that we support at this moment:


=head2 CHAPTERS, SECTIONS, etc.

Very simply, start your line with one or multiple hash marks (#).
The number you use defines the level of the section heading. Also,
B<TeXDown> will create labels for each section, where the label
is the same as the section name, with all spaces replaced by dashes:

# This is a part

becomes:

\part{This is a part}\label{This-is-a-part}

Likewise, for 

## Section

### Subsection

#### Subsubsection

##### Paragraph

###### Subparagraph

Optionally, you can add short forms of the headings - those that
are going to be put into the table of contents - for all levels
like so:

##[Shortform] Longform

becomes:

\section[Shortform]{Longform}\label{Longform}

Alternatively, you can exclude the section from the table of
contents by way of the starred form:

##* Section Heading

becomes:

\section*{Section Heading}\label{Section Heading}


=head2 COMMENTS

HTML comments like <!-- ... --> are removed and replaced by a
single space. Scrivener needs those to not show some content
in its scrivenings view, so that's why it makes sense to keep
them in Scrivener, and only remove them when parsing.


=head2 QUOTES

Single and double quotes are converted to their typographical
forms:

    'abc' => `abc'
    "abc" => ``abc''

As a bonus triple quotes are correctly transformed into their
typographical versions:

    '''abc''' => ``\thinspace`abc'\thinspace''


=head2 FOOTNOTES

Footnotes are written between double underscores like so:

    __This is a footnote__  => \footnote{This is a footnote}


=head2 CITATIONS

Citations are the strongest part of using Markdown over LaTeX.
Consider this scenario:

  \citeauthor{Nott:2016} wrote about Markdown, that ``citations
  are the strongest part of using Markdown over LaTeX.'' 
  (\citeyear[20-30]{Nott:2016}) He also holds that using a simple
  Perl script, you can \emph{very much} simplify the problem
  \citep[ibd.]{Nott:2016}.

The previous paragraph, in B<TeXDown> Markdown, can be written like
this:

  [a#Nott:2016] wrote about Markdown, that "citations
  are the strongest part of using Markdown over LaTeX."
  (20-30)[yp#Nott:2016] He also holds that using a simple
  Perl script, you can **very much** simplify the problem
  [i#Nott:2016].

So here are the citations that we support. Let's assume that
Nott:2016 is our citation key (you just comma-separate them
if you have more than one).

=head3 SIMPLE FORMS

=head4 \citep

  [#Nott:2016]    => \citep{Nott:2016}
  [p#Nott:2016]   => \citep{Nott:2016}

=head4 \citeauthor

  [a#Nott:2016]   => \citeauthor{Nott:2016}

=head4 \cite

  [c#Nott:2016]   => \cite{Nott:2016}

=head4 \citet

  [t#Nott:2016]   => \citet{Nott:2016}

=head4 \citeyear

  [y#Nott:2016]   => \citeyear{Nott:2016}
  [yp#Nott:2016]   => (\citeyear{Nott:2016})

The above [yp#] form is a bonus since it is very often used
after actual quotations (see samples above.) You can memorize
it using "year, parenthesis."

=head3 PAGE RANGES

=head4 Simple Page Ranges

If you want to add page ranges to it, you add those in 
round parentheses, to any of the above forms. So for example:

  (20-30)[yp#Nott:2016] => (\citeyear[20-30]{Nott:2016})

=head4 Annotated Page Ranges

Of course, you can really write about anything into there:

  (20-30, emphasis ours)[yp#Nott:2016]

=head4 Shorthand for ibd.

If you are referring to the same thing again, you can do this
- with all forms - by adding an "i" just in front of the "#":

  [i#Nott:2016]         => \citep[ibd.]{Nott:2016}
  [ypi#Nott:2016]       => (\citeyear[ibd.]{Nott:2016})


=head2 LABELS

To add a label, you simply do this:

  [l# A Label]          => \label{A-Label}

Leading spaces are removed, and other spaces are converted to
dashes, just like when using labels that are automatically
generated along with section headers.


=head2 REFERENCES

References are simple. Assume you somewhere have a label "abc":

  [r# abc]    => \ref{abc}
  [vr# abc]   => \vref{abc}
  [pr# abc]   => \pageref{abc}
  [er# abc]   => \eqref{abc}

=head2 EMPHASIS

Finally, for emphasizing things, you can do this:

  **This is emphasized**    => \emph{This is emphasized}


=head2 GOING CRAZY

Let's do a crazy thing: Use a two line B<TeXDown> file:

(As [a#Nott:2016] said, "TeXdown is quite easy." 
(20)[yp#Nott:2002])__[a#Nott:2005]  had **already** said:  "This is the **right** thing to do" (20--23, **emphasis** ours)[ypi#Nott:2016]____Debatable.__

and parse it by B<TeXDown>;

cat crazy.tex | ./texdown.pl

(As \citeauthor{Nott:2016} said, ``TeXdown is quite easy.'' 
(\citeyear[20]{Nott:2002}))\footnote{\citeauthor{Nott:2005} had \emph{already} said: ``This is the \emph{right} thing to do'' (20--23, \emph{emphasis} ours)(\citeyear[ibd.]{Nott:2016})}\footnote{Debatable.}

Agreed, both are probably not all that readable, but it makes
the point that you can even nest those commands.

=head2 TROUBLE-SHOOTING

If you see problems with the parser, then a good idea might be to
do just what I had shown in the previous section: Just put the
problematic code into a text file and run it manually. If you
find problems, try to fix them with the %parser (see source code),
and if you don't want to do that, you can always use plain LaTeX
code anyway!


=cut
