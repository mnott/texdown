#!/usr/bin/env perl -w
###################################################
#
# About the documentation:
#
# Created like
#
# pod2markdown.pl <texdown.pl >README.md
#
# Using the excellent podmarkdown by Randy Stauner.
#
###################################################


my $pod2md = "pod2markdown.pl";    # Must be in $PATH

=head1 NAME

TeXDown - Markdown for LaTeX and Instrument Scrivener

=head1 VERSION

Version 0.0.2

=head1 LICENCE AND COPYRIGHT
Copyright (c) 2016 - 2017 Matthias Nott (mnott (at) mnsoft.org).

Licensed under WTFPL.

=cut

###################################################
#
# Dependencies
#
###################################################

=head1 DEPENDENCIES

=cut

use 5.24.0;
use strict;
use warnings;

binmode STDOUT, ":utf8";
use utf8;
use Carp qw(carp cluck croak confess);
use feature qw(say);
use Data::Dump "pp";
use Pod::Usage;
use Module::Load;

###################################################
#
# Relative Library Directory Lookup
#
###################################################

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname( Cwd::abs_path $0) . '/lib';

###################################################
#
# TeXDown modules
#
###################################################

use TeXDown::TConfig;
use TeXDown::TMain;
use TeXDown::TParser;

###################################################
#
# Logger
#
###################################################

use Log::Log4perl qw(get_logger :levels);
Log::Log4perl->init( dirname( abs_path $0) . "/log4p.ini" );

my $log = get_logger("TeXDown");

if ( exists $ENV{LOGLEVEL} && "" ne $ENV{LOGLEVEL} ) {
    $log->level( uc $ENV{LOGLEVEL} );
}


###################################################
#
# Parse the Command Line.
#
# - Uses TeXDown::TConfig
# - Exposes variables as $cfg->get("x") etc.
#   (which can be arrays, depending on how they
#   have been filled through GetOptions). In any
#   case, they can always be iterated either as
#   array or retrieved as single value.
#
###################################################

use Config::Simple;
use Getopt::Long;

#
# Instantiate the Configuration holder
#
our $cfg = TeXDown::TConfig->new;

#
# Instantiate the Parser
#
our $parser = TeXDown::TParser->new;

#
# Get the command line options
#
GetOptions(
    'c|cfg:s'           => sub { $cfg->append(@_); },
    'i|id:s{,}'         => sub { $cfg->append(@_); },
    'l|list'            => sub { $cfg->append(@_); },
    'p|project:s{,}'    => sub { $cfg->append(@_); },
    'a|all'             => sub { $cfg->append(@_); },
    's|search:s'        => sub { $cfg->append(@_); },
    'n|no|nothing'      => sub { $cfg->append(@_); },
    'v|verbose'         => sub { $cfg->append(@_); },
    'parser:s'          => sub { $cfg->append(@_); },
    'doc|documentation' => sub { $cfg->append(@_); },
    'h|?|help'          => sub { $cfg->append(@_); },
    'man'               => sub { $cfg->append(@_); },
) or pod2usage(2);
pod2usage(1) if $cfg->contains_key("h");

pod2usage( -exitval => 0, -verbose => 2 ) if $cfg->contains_key("man");

#
# Shortcut for myself to recreate the documentation
# without having to remember how it was done.
#
if ( $cfg->get("doc") ) {
    system("$pod2md < $0 >README.md");
    exit 0;
}


###################################################
#
# Run the Main Program
#
###################################################

#
# Load the Parser
#
$parser->load();

#
# Load the Main Program
#
my $texdown = TeXDown::TMain->new;

#
# Run or Filter?
#
if ( -t STDIN ) {
    if ( @ARGV > 0 ) {
        $texdown->run(@ARGV);
    }
    else {
        pod2usage(2);
    }
}
else {
    while (<STDIN>) {
        my $line = $_;
        $line = $parser->parse($line) unless $cfg->get("n");
        print $line;
    }
}



$log->trace("Done.");

exit 0;










###################################################
#
# Documentation
#
###################################################

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

             To do so, TeXDown does several things:

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
   -d               debug (alternatives: -debug)
   -n               do not actually parse Markdown into LaTeX
                    (alternative: -no, -nothing)

   Scrivener Options:

   -p               The scrivener object name(s) (or id(s)) to start with.
                    (alternative: -project)
   -a               Only include all objects, not only those that
                    were marked as to be In Compilation.
                    (alternative: -all)
   -l               Only list the ids and section titles of what would
                    have been included (alternative: -list)
   -c               Use a configuration file to drive TeXDown.
                    (alternative: -cfg)
   -i               Resolve the Scrivener path for a given document id(s).
                    (alternative: -id)
   -s               Search the Scrivener Content.
                    (alternative: -search)

   Other Options:

   -parser          Use a specific parser.cfg
   -documentation   Recreate the README.md (needs pod2markdown)


=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-d>

Print debug information to stderr. You can set the log level as
any of OFF, FATAL, ERROR, WARN, INFO, DEBUG, TRACE, ALL. If you
don't specify a log level, DEBUG is used. If you don't use the
parameter, whatever is specified in log4p.ini is used (probably
WARN, but of course you can change that). The more
you go from OFF to ALL, the more information you will get.

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

  ./texdown.pl Dissertation -p Frontmatter Content Backmatter

or

  ./texdown.pl Dissertation -p Frontmatter -p Content -p Backmatter

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

  ./texdown.pl Dissertation -p /LaTeX/Articles/Frontmatter Literature /LaTeX/Articles/Backmatter

As a side effect, if you want to print out the entire object hierarchy
of your scrivener database, you can do this:

  ./texdown.pl Dissertation -p / -l

This will also give you a clue about the associated RTF file names,
as the IDs that are listed correspond directly to the rtf file names
living in the Files/Docs subdirectory of the Scrivener folder.

Finally, if you pass an integer number - like 123 - as project,
this will be treated as if you wanted to directly address the
Scrivener asset id as reported by -l. This option allows for
incredible shorthand, but should rather be used for testing:
those ids, after all, can change, and you should not base your
logic on them.

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
  ; parser=parser.cfg

  [Dissertation]
  p=Dissertation

  [rd]
  ; Research Design
  p=/LaTeX/Article/Frontmatter, "Research Design", /LaTeX/Article/Backmatter

  [roilr]
  ; ROI - Literature Review
  p=/LaTeX/Article/Frontmatter, "ROI - Literature Review", /LaTeX/Article/Backmatter

Let's assume we have saved this file as Dissertation.ini, into
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
and is named Dissertation.ini. It will also assume that you expect to
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

  ./texdown.pl Dissertation -l -c Dissertation.ini

This is going to look for the Dissertation.ini configuration file,
in some location (you can now give a complete path to it), and since
we yet forgot again, which project to actually use, it is going to
default to the Dissertation scope in that file.

Let's be really specific and also say, which project to use with
that configuration file:

  ./texdown.pl Dissertation -l -c Dissertation.ini -p roilr

Of course, you can now be really crazy and run a number of projects
in a row:

  ./texdown.pl Dissertation -l -c -p roilr rd Dissertation

This will tell B<TeXDown>, again, to use Dissertation.ini out of the
same directory where the referred to Dissertation.scriv lives, and to
then process the scopes roilr, rd, and Dissertation, in that order.

Of course, this somehow only makes sense if you can specify a different
output file, or intermediate processing, which I've not yet implemented.
But that's, at the end, once it is done, the what [GLOBAL] section will
be for: There we'll be able to specify e.g. the default LaTeX command
to process the output.


=item B<-i>

This option allows you to find the path to a Scrivener document in
your library, if you only know its document id. This is useful if
you use, for example, a find command on the command line, searching
for a given content. So for example, let's define a bash command
that will allow you to search for file contents:

  ff () { find . -type f -iname "*$1" -print0 | xargs -0 grep -i "$2" ; }

Just enter the above line at the command line. If you like it, you can
put it into your ~/.profile

Let's use that to find some content in our Scrivener directory. I am
looking for all the files where I happen to have used the command
\parta. Here's how to look for it (from the current directory):

  ff rtf parta
  ./Dissertation.scriv/Files/Docs/216.rtf:\\def\\parta\{Thesis\}\
  ./Dissertation.scriv/Files/Docs/281.rtf:\\def\\parta\{Thesis\}\

etc. So this is great because it shows me where I was using that
command. The question of course is, where will I find these documents
from within Scrivener? Here's how:

  ./texdown.pl Dissertation -i 216 281
  /Dissertation/
  /Trash/LaTeX - Front Matter/

Thus we can now easily look at the /Dissertation node, which contains
that \parta statement, while we can probably ignore the other document
that was found in the trash.


=item B<-s>

This option is an extension on the manual grep of the B<-i> option:
It allows you to perform a search on any of your scrivener projects.
The search string can be plain text, or even a regular expression.
So here's how we are going to search for all the sections that
we have in our roilr project as defined per configuration file:

  ./texdown.pl Dissertation -c -p roilr  -s "section"
  [     322] /ROI - Literature Review/coakes - 2011 - sustainable innovation and right to market: \section[Coakes, Smith, and Alwis (201
  [     335] /ROI - Literature Review/desouza - 2011 - intrapreneurship managing ideas within your: \section[Desouza (2011)]{\citet{Desouz
  [     348] /ROI - Literature Review/dyduch - 2008 - corporate entrepreneurship measurement for improving organizational: \section[Dyduch (2008)]{\citet{Dyduch:
  [     361] /ROI - Literature Review/hornsby - 2002 - middle managers' perception of the internal environment: \section[Hornsby, Kuratko and Zahra (2
  [     175] /ROI - Literature Review/zahra - 2015 - corporate entrepreneurship as knowledge creation and conversion: \section[Zahra (2015)]{\citet{Zahra:20
  [     167] /ROI - Literature Review/zahra - 1993 - a conceptual model of entrepreneurship as firm behavior: \section[Zahra (1993)]{\citet{Zahra:19

Let's assume we want to see only those sections which have Zahra
in them:

  ./texdown.pl Dissertation -c -p roilr -s "section.*Zahra"
  [     361] /ROI - Literature Review/hornsby - 2002 - middle managers' perception of the internal environment: \section[Hornsby, Kuratko and Zahra (2
  [     175] /ROI - Literature Review/zahra - 2015 - corporate entrepreneurship as knowledge creation and conversion: \section[Zahra (2015)]{\citet{Zahra:20
  [     167] /ROI - Literature Review/zahra - 1993 - a conceptual model of entrepreneurship as firm behavior: \section[Zahra (1993)]{\citet{Zahra:19

Let's search for those where Zahra is the first author, measured
by that it is close to the section tag:

  ./texdown.pl Dissertation -c -p roilr -s "section.{1,5}?Zahra"
  [     175] /ROI - Literature Review/zahra - 2015 - corporate entrepreneurship as knowledge creation and conversion: \section[Zahra (2015)]{\citet{Zahra:2015aa}}
  [     167] /ROI - Literature Review/zahra - 1993 - a conceptual model of entrepreneurship as firm behavior: \section[Zahra (1993)]{\citet{Zahra:1993aa}}

Finally, as we can combine this with the other command line parameters,
let's not have TeXDown parse the markdown code first, but search for
all places where we may have left \section commands in plain LaTeX
code:

  ./texdown.pl Dissertation -p / -n -s '\\section'
  [      94] /Dissertation/LaTeX - Front Matter/01 - Appendix/03 - Symbols/00 - Manual: % \section{Some Greek symbols}

Don't forget to use four \\\\ if you use double quotes, or two \\,
if you use single quotes.


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

If you don't like having your footnotes directly in your text,
in Scrivener, you can also add footnotes to any place of the
text, using Scrivener's footnote option. B<TeXDown> will
detect these (not the comments, only the footnotes), and
automatically convert them into Markdown, and then onwards
to LaTeX. If you have newlines in your Scrivener footnotes,
these are going to be removed. Since the footnotes are
first converted to Markdown, they themselves can also contain
Markdown.


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
