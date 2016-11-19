#!/opt/local/bin/perl          # <= Adapt if needed
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
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use RTF::TEXT::Converter;
use XML::LibXML;
use Tie::IxHash;

my $project = "";
my $dontparse;
my $debug;
my $man = 0;
my $help = 0;

my $itemlevel   = 0; # for itemizes: level; 0, 1 or 2
my $currentitem = ""; # current bullet kind: "", "m" or "t"


#
# Parse command line
#
GetOptions ('project:s'         => \$project,   # if scriv, document folder to start with
            'dontparse'         => \$dontparse, # if set, dont parse md
            'v|d|debug|verbose' => \$debug,     # if set, print some debug info
            'help|?|h'          => \$help, 
            'man'               => \$man,
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

  '^#\* (.*?)$' => '"\part*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^##\* (.*?)$' => '"\chapter*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^###\* (.*?)$' => '"\section*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^####\* (.*?)$' => '"\subsection*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^#####\* (.*?)$' => '"\subsubsection*{$1}\label{".nomarkdown(nospace($1))."}"',
  '^######\* (.*?)$' => '"\paragraph*{$1}\label{".nomarkdown(nospace($1))."}"',  

  '^#\[([^]]*)\] (.*?)$' => '"\part[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^##\[([^]]*)\] (.*?)$' => '"\chapter[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^###\[([^]]*)\] (.*?)$' => '"\section[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^####\[([^]]*)\] (.*?)$' => '"\subsection[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^#####\[([^]]*)\] (.*?)$' => '"\subsubsection[$1]{$2}\label{".nomarkdown(nospace($2))."}"',
  '^######\[([^]]*)\] (.*?)$' => '"\paragraph[$1]{$2}\label{".nomarkdown(nospace($2))."}"',

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
# Decide which processing ot use
#
if (-t STDIN) {
  if (@ARGV > 0) {
    runOnFiles (@ARGV);
  } else {
    pod2usage(1);
  }
} else {
  runAsFilter();
}


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
# We also are going to parse out any 
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
# Regular Expression parser usign the %parser
# Parse table
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
# Do the processing on files
# from the command line
#
sub runOnFiles {
  while ($_ = shift(@ARGV)) {
    if (-e "$_" || -e "$_.scriv") {
      my ($fname, $fpath, $fsuffix) = fileparse($_, qr/\.[^.]*/);
      my $basename = basename($_, qr/\.[^.]*/);
      my $dirname = dirname($_);

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

        #
        # If we don't have a project, as a fallback, we default
        # to the $fname
        # 
        $project = $fname if ($project eq "");

        parseScrivener ($dir, $file);
      } elsif (-f "$found") {
        my $dir  = "$fpath";
        my $file = "$found";
        parsePlain ($dir, $file);
      } 
    }
  }  
}


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
# Parse a Scrivener Directory
#
sub parseScrivener {
  my ($dir, $file) = (@_);
  if ($debug) {
    print "% Scrivener Processing...\n";
    print "% Project    : $project\n";
    print "% Directory  : $dir\n";
    print "% File       : $file\n";
  }

  my $doc = XML::LibXML->load_xml(location => $file);

  foreach my $binderItem ($doc->findnodes('//BinderItem[Title/text() = "'."$project".'"]//BinderItem[@Type="Text"]')) {
    my $docId    = $binderItem->getAttribute("ID");
    my $docTitle = $binderItem->findnodes('./Title')->to_literal;
  
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
# Parse a Plain File
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
# Convert a file from rtf to a txt string.
# 
sub rtf2txt {
	my $file = shift;
	my $result;
	my $self = new RTF::TEXT::Converter(output => \$result);
	$self->parse_stream($file);
	return $result;
}



#GetOptions ('project:s'         => \$project,   # if scriv, document folder to start with
#            'dontparse'         => \$dontparse, # if set, dont parse md
#            'v|d|debug|verbose' => \$debug,     # if set, print some debug info
#            'help|?|h'          => \$help, 
#            'man'               => \$man,
#) or pod2usage(2);

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

             To do so, texdown.pl does several things:

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
   -help            brief help message (alternatives: ?, -h)
   -man             full documentation (alternatives: -m)
   -v               verbose (alternatives: -d, -debug, -verbose)
   -dontparse       do not actually parse Markdown into LaTeX

   -project         The scrivener folder name to start with

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-v>

Put LaTeX comments into the output with the name of the file that
has been parsed.

=item B<-dontparse>

Don't actually parse the Markdown Code into LaTeX code.

=item B<-project>

The root folder in a Scrivener database within the processing
should start. If not given, and if yet running on a Scrivener
database, the script will assume the root folder to have the
same name as the Scrivener database.

=back


=head1 DESCRIPTION

=head2 INSTALLATION

Put the script somewhere and make it executable:

  cp texdown.pl ~/Desktop
  chmod 755 ~/Desktop/texdown.pl

(Desktop is probably not the best place to put it, but just to
make the point.) Also, make sure that you reference the right
version of Perl. At the beginning of the script, you see a
reference to /opt/local/bin/perl. Use, on the command line,
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
TeXdown, use the upgrade only if an install failed.


=head2 RUNNING as a FILTER

When running as a filter, B<texdown.pl> will simply take the
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

  cat document.tex | ./texdown.pl -dontparse | ./texdown.pl -v

=head2 RUNNING as a SCRIPT

If running as a script, B<texdown.pl> will take all parameters
that it does not understand as either command line parameters
or as values thereof, and try to detect whether these are files.
It will then process those files one after another, in the order
they are given on the command line. The output will again go to
STDOUT. So for example:

  ./textdown.pl -v test.tex test2.tex test3.tex >document.tex

In case you want to run B<texdown.pl> against data that is in a
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

So what B<texdown.pl> will do is that it will first detect whether
a file given on the command line is actually a Scrivener database,
then it will try to locate the B<.scrivx> file within that, to 
then parse it in order to find out the root folder that you wanted
the processing to start at. It will then, one after another,
try to locate the related rtf files, convert them to plain text,
and then parse those.

So for example, assuming you have a Scrivener database B<Dissertation>
in the current directory, you can do this:

  ./texdown.pl Dissertation

Notice that we did not use the -project parameter to specify the root
folder at which you want to start your processing. If this is the
case, B<texdown.pl> will try to locate a folder that has the same
name as the database - in the above example, it will just use
B<Dissertation>.

So if you want to specify another root folder, you can do so:

  ./texdown.pl Dissertation -project Content

Piping the result into some file:

  ./texdown.pl Dissertation -project Content >document.tex

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

At this moment, B<texdown.pl> works on single lines only. In other
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
B<texdown.pl> will create labels for each section, where the label
is the same as the section name, with all spaces replaced by dashes:

# This is a part

becomes:

\part{This is a part}\label{This-is-a-part}

Likewise, for 

## Section

### Subsection

#### Subsubsection

##### Paragraph

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

The previous paragraph, in TeXdown Markdown, can be written like
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

Let's do a crazy thing: Use a two line TeXdown file:

(As [a#Nott:2016] said, "TeXdown is quite easy." 
(20)[yp#Nott:2002])__[a#Nott:2005]  had **already** said:  "This is the **right** thing to do" (20--23, **emphasis** ours)[ypi#Nott:2016]____Debatable.__

and parse it by TeXdown;

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
