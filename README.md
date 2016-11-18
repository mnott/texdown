# NAME

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

# SYNOPSIS

./texdown.pl \[options\] \[files ...\]

Command line parameters can take any order on the command line.

    Options:
      -help            brief help message (alternatives: ?, -h)
      -man             full documentation (alternatives: -m)
      -v               verbose (alternatives: -d, -debug, -verbose)
      -dontparse       do not actually parse Markdown into LaTeX

      -project         The scrivener folder name to start with

# OPTIONS

- **-help**

    Print a brief help message and exits.

- **-man**

    Prints the manual page and exits.

- **-v**

    Put LaTeX comments into the output with the name of the file that
    has been parsed.

- **-dontparse**

    Don't actually parse the Markdown Code into LaTeX code.

- **-project**

    The root folder in a Scrivener database within the processing
    should start. If not given, and if yet running on a Scrivener
    database, the script will assume the root folder to have the
    same name as the Scrivener database.

# DESCRIPTION

## INSTALLATION

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
on your system are listed at the top of **texdown.pl**:

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

## RUNNING as a FILTER

When running as a filter, **texdown.pl** will simply take the
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

## RUNNING as a SCRIPT

If running as a script, **texdown.pl** will take all parameters
that it does not understand as either command line parameters
or as values thereof, and try to detect whether these are files.
It will then process those files one after another, in the order
they are given on the command line. The output will again go to
STDOUT. So for example:

    ./textdown.pl -v test.tex test2.tex test3.tex >document.tex

In case you want to run **texdown.pl** against data that is in a
Scrivener database, you just pass the directory of that database
to it. So let's assume we've a Scrivener database **Dissertation**
in the current directory.

This actually means that in reality, you would have a directory
**Dissertation.scriv**, within which, specifically, you would find
a file **Dissertation.scrivx**, along with some other directories.
This **Dissertation.scrivx** is actually an XML file which we are
going to parse in order to locate the content that we want to
parse from LaTeX containing Markdown, to only LaTeX. The XML
file **Dissertation.scrivx** basically contains the mapping
between the names of objects that you give in the Scrivener
Application, and the actual representations of those files on
the disk. Scrivener holds its files in a directory like
**Dissertation.scriv/Files/Docs** with numbered filenames like
123.rtf.

So what **texdown.pl** will do is that it will first detect whether
a file given on the command line is actually a Scrivener database,
then it will try to locate the **.scrivx** file within that, to 
then parse it in order to find out the root folder that you wanted
the processing to start at. It will then, one after another,
try to locate the related rtf files, convert them to plain text,
and then parse those.

So for example, assuming you have a Scrivener database **Dissertation**
in the current directory, you can do this:

    ./texdown.pl Dissertation

Notice that we did not use the -project parameter to specify the root
folder at which you want to start your processing. If this is the
case, **texdown.pl** will try to locate a folder that has the same
name as the database - in the above example, it will just use
**Dissertation**.

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
the extension **.scriv**, whether you have absolute or relative paths,
or whether you have trailing slashes. It will just try to do the
right thing if you call it with something stupid like

    ./texdown.pl $(pwd)/./Dissertation.scriv/./././

You can also specify multiple Scrivener databases; at this moment,
they will all share the same root folder to start with.

# CONFIGURATION

If you want to add your own parsers, have a look at the source code
of the file. It is pretty well documented.

# LIMITATIONS

At this moment, **texdown.pl** works on single lines only. In other
words, we do not support tags that span multiple lines, and we do
not yet support itemizes, enumerates (while those could be done with
line by line processing using a carry flag, we just didn't implement
it so far), or tables.

Practically, this means that you will e.g. have to have your
footnotes in one line, like \_\_This is a footnote\_\_ - of course
you can at any time also use actual LaTeX commands, and if you
do not want to see them in Scrivener, you can just escape them
using &lt;!-- \\footnote{This is another footnote.} -->

# SYNTAX

The Markdown code that this program uses is neither
MultiMarkDown (mmd) nor Pandoc compatible, since these
were too limited as to their support of LaTeX.

Here are the options that we support at this moment:

## CHAPTERS, SECTIONS, etc.

Very simply, start your line with one or multiple hash marks (#).
The number you use defines the level of the section heading. Also,
**texdown.pl** will create labels for each section, where the label
is the same as the section name, with all spaces replaced by dashes:

\# This is a part

becomes:

\\part{This is a part}\\label{This-is-a-part}

Likewise, for 

\## Section

\### Subsection

\#### Subsubsection

\##### Paragraph

Optionally, you can add short forms of the headings - those that
are going to be put into the table of contents - for all levels
like so:

\##\[Shortform\] Longform

becomes:

\\section\[Shortform\]{Longform}\\label{Longform}

Alternatively, you can exclude the section from the table of
contents by way of the starred form:

\##\* Section Heading

becomes:

\\section\*{Section Heading}\\label{Section Heading}

## COMMENTS

HTML comments like &lt;!-- ... --> are removed and replaced by a
single space. Scrivener needs those to not show some content
in its scrivenings view, so that's why it makes sense to keep
them in Scrivener, and only remove them when parsing.

## QUOTES

Single and double quotes are converted to their typographical
forms:

    'abc' => `abc'
    "abc" => ``abc''

As a bonus triple quotes are correctly transformed into their
typographical versions:

    '''abc''' => ``\thinspace`abc'\thinspace''

## FOOTNOTES

Footnotes are written between double underscores like so:

    __This is a footnote__  => \footnote{This is a footnote}

## CITATIONS

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

### SIMPLE FORMS

#### \\citep

    [#Nott:2016]    => \citep{Nott:2016}
    [p#Nott:2016]   => \citep{Nott:2016}

#### \\citeauthor

    [a#Nott:2016]   => \citeauthor{Nott:2016}

#### \\cite

    [c#Nott:2016]   => \cite{Nott:2016}

#### \\citet

    [t#Nott:2016]   => \citet{Nott:2016}

#### \\citeyear

    [y#Nott:2016]   => \citeyear{Nott:2016}
    [yp#Nott:2016]   => (\citeyear{Nott:2016})

The above \[yp#\] form is a bonus since it is very often used
after actual quotations (see samples above.) You can memorize
it using "year, parenthesis."

### PAGE RANGES

#### Simple Page Ranges

If you want to add page ranges to it, you add those in 
round parentheses, to any of the above forms. So for example:

    (20-30)[yp#Nott:2016] => (\citeyear[20-30]{Nott:2016})

#### Annotated Page Ranges

Of course, you can really write about anything into there:

    (20-30, emphasis ours)[yp#Nott:2016]

#### Shorthand for ibd.

If you are referring to the same thing again, you can do this
\- with all forms - by adding an "i" just in front of the "#":

    [i#Nott:2016]         => \citep[ibd.]{Nott:2016}
    [ypi#Nott:2016]       => (\citeyear[ibd.]{Nott:2016})

## LABELS

To add a label, you simply do this:

    [l# A Label]          => \label{A-Label}

Leading spaces are removed, and other spaces are converted to
dashes, just like when using labels that are automatically
generated along with section headers.

## REFERENCES

References are simple. Assume you somewhere have a label "abc":

    [r# abc]    => \ref{abc}
    [vr# abc]   => \vref{abc}
    [pr# abc]   => \pageref{abc}
    [er# abc]   => \eqref{abc}

## EMPHASIS

Finally, for emphasizing things, you can do this:

    **This is emphasized**    => \emph{This is emphasized}

## GOING CRAZY

Let's do a crazy thing: Use a two line TeXdown file:

(As \[a#Nott:2016\] said, "TeXdown is quite easy." 
(20)\[yp#Nott:2002\])\_\_\[a#Nott:2005\]  had \*\*already\*\* said:  "This is the \*\*right\*\* thing to do" (20--23, \*\*emphasis\*\* ours)\[ypi#Nott:2016\]\_\_\_\_Debatable.\_\_

and parse it by TeXdown;

cat crazy.tex | ./texdown.pl

(As \\citeauthor{Nott:2016} said, \`\`TeXdown is quite easy.'' 
(\\citeyear\[20\]{Nott:2002}))\\footnote{\\citeauthor{Nott:2005} had \\emph{already} said: \`\`This is the \\emph{right} thing to do'' (20--23, \\emph{emphasis} ours)(\\citeyear\[ibd.\]{Nott:2016})}\\footnote{Debatable.}

Agreed, both are probably not all that readable, but it makes
the point that you can even nest those commands.

## TROUBLE-SHOOTING

If you see problems with the parser, then a good idea might be to
do just what I had shown in the previous section: Just put the
problematic code into a text file and run it manually. If you
find problems, try to fix them with the %parser (see source code),
and if you don't want to do that, you can always use plain LaTeX
code anyway!
