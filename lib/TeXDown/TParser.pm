package TeXDown::TParser;

=pod

=head1 NAME

TeXDown::TParser: parse TeXDown.

=head1 DESCRIPTION

This class provides for parsing of TeXDown markup.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...; $cfg
    # would be an instance of TeXDown::TConfig

    my $parser = TeXDown::TParser->new( cfg => $cfg );


See L<"parse"> for more description.


=head1 METHODS

=cut



use warnings;
use strict;

#use version; our $VERSION = qv('0.0.3');

binmode STDOUT, ":utf8";
use utf8;
use Carp qw(carp cluck croak confess);
use feature qw(say);
use Data::Dump "pp";
use Pod::Usage;
use File::Basename;
use Cwd qw(abs_path);

use Moose;
with 'MooseX::Log::Log4perl';

use namespace::autoclean -except => sub { $_ =~ m{^t_.*} };

use TeXDown::TConfig;
use TeXDown::TUtils qw/ t_as_string /;


=begin testing SETUP

###################################################
#
# Test Setup
#
###################################################

my $MODULE       = 'TeXDown::TParser';

my @DEPENDENCIES = qw / TeXDown::TMain
                        TeXDown::TConfig
                        TeXDown::TUtils
                        TeXDown::TParser
                        TeXDown::TFileResolver
                      /;

my $INI          = 't/texdown-test.ini';

# Mostly dynamic construction of module path
###################################################

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname( abs_path $0) . '/../lib';

binmode STDOUT, ":utf8";
use utf8;
use feature qw(say);
use Data::Dump "pp";
use Module::Load;

###################################################
#
# Set up logging
#

use Log::Log4perl qw(get_logger :levels);
Log::Log4perl->init( dirname( abs_path $0) . "/../log4p.ini" );


# Load Dependencies and set up loglevels

foreach my $dependency (@DEPENDENCIES) {
    load $dependency;
    if ( exists $ENV{LOGLEVEL} && "" ne $ENV{LOGLEVEL} ) {
        get_logger($dependency)->level( uc $ENV{LOGLEVEL} );
    }
}

my $log = get_logger($MODULE);

# For some reason, some test
# runs have linefeed issues
# for their first statement

print STDERR "\n";

#
###################################################

###################################################
#
# Initial shared code for all tests of this module
#
###################################################

my $cfg      = TeXDown::TConfig->new();

$cfg->load($INI);

my $parser = TeXDown::TParser->new ( cfg => $cfg );

$parser->load();

=end testing

=cut


has cfg_of => (
    is   => 'ro',
    isa  => 'TeXDown::TConfig',
    lazy => 0,
);

has parser_of => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
    lazy    => 0,
);

has 'xparser' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] }, );
has 'itemlevel'   => ( is => 'rw', isa => 'Int', default => 0 );
has 'currentitem' => ( is => 'rw', isa => 'Str', default => "" );

=begin testing Construct

    ok( defined($parser) && ref $parser eq $MODULE, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;

    # If we have been given an configuration object, we make it
    # available
    if ( exists $arg_ref->{cfg} ) {
        $self->{cfg_of} = $arg_ref->{cfg};
    }
}

sub load {
    my ( $self, $parser, $arg_ref ) = @_;

    my $cfg = $self->{cfg_of};

    # If we have been given a parser location, we use
    # that one
    if ( defined $parser && $parser ne "" ) {
        $cfg->set( "parser", $parser );
    }
    else {
        if ( $cfg->contains_key("parser") ) {
            $parser = $cfg->get("parser");
        }
        else {
            $parser = "parser.cfg";
            $cfg->set( "parser", $parser );
        }
    }

    #
    # Resolve the Parser File
    #
    my $resolver = TeXDown::TFileResolver->new( cfg => $cfg );
    my ($d, $parserfile) = $resolver->resolve_files($parser);

    #
    # If that lookup did not work, e.g. because we were called
    # with no parser specification through command line or config
    # file, we are going to use parser.cfg but may not be calling
    # the program from the program's root directory. Hence, we
    # explicitly try to find parser.cfg there.
    #
    if (! defined $parserfile || !-f $parserfile) {
        $parserfile = dirname( abs_path $0) . '/' . $parser;
    }

    if (!defined $parserfile || !-f $parserfile ) {
        pod2usage(
            {   -message =>
                    "\nParser Configuration file $parser not found\n",
                -exitval => 2,
            }
        );
    }

    #
    # Read the Parser File
    #
    # TODO: Experiment wrt nomarkdown / nospace to put them not inside
    #       this module, so that the user can overwrite this from the parser
    #       configuration file
    open my $info, $parserfile or die "Could not open $parserfile: $!";
    $self->log->info("Loading Parser: $parserfile");

    while ( my $line = <$info> ) {
        $line =~ s/^#.*$//g;            # Lines starting as comments
        $line =~ s/\s+#.*$//g;          # In-line comments
        $line =~ s/'(.*)',\s*$/$1/g;    # Outer single quotes
        $line =~ s/\\'/'/g;             # Reading escaped single quotes
        $line =~ s/nomarkdown\(/\$self->nomarkdown(/g;
        $line =~ s/nospace\(/\$self->nospace(/g;
        if ( $line =~ m/^(.*)'\s*=>\s*'(.*)$/ ) {
            my %pline;
            $pline{"s"}  = "$1";
            $pline{"r"}  = "$2";
            $pline{"$1"} = "$2";
            push @{ $self->parser_of }, \%pline;
        }
    }
    close $info;
}


=head2 parse

C<parse>
regular expression parser using the parse table loaded from file.

Input       : The text content to parse

Returns     : The parsed content

=cut


sub parse {
    my ( $self, $input, $arg_ref ) = @_;

    my $output;

    for ( split /^/, $input ) {
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

        if ( $line =~ m/(.*?)%(.*)$/ ) {
            $content = $1;
            $comment = "%" . $2;
        }

        for my $pline ( @{ $self->parser_of } ) {
            my $search  = %$pline{"s"};
            my $replace = %$pline{"r"};
            $replace =~ s/\\/\\\\/g;
            $content =~ s/$search/$replace/eeg;
        }

        $content =~ s/!NOCOMMENT!/\%/g;
        $comment =~ s/!NOCOMMENT!/\%/g;

        #
        # Test for itemizes
        #
        $content = $self->itemize($content);

        #
        # Reconcatenate content and comments (if any)
        #
        $output .= "$content$comment\n";
    }
    return $output;

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
# TODO: Experiment how to put this not inside this module,
#       so that the user can overwrite this from the parser
#       configuration file
#
# $str   : The string to parse
# returns: The parsed string with spaces replaced by -
#
sub nospace {
    my ( $self, $str, $arg_ref ) = @_;
    $self->log->trace( $self->t_as_string($arg_ref) );

    $str =~ s/ /-/g;

    return $str;
}


#
# Drop any Markdown (for auto generated header labels)
#
# TODO: Experiment how to put this not inside this module,
#       so that the user can overwrite this from the parser
#       configuration file
#
sub nomarkdown {
    my ( $self, $str, $arg_ref ) = @_;
    $self->log->trace( $self->t_as_string($arg_ref) );

    $str =~ s/\[[^\]]*\]//g;

    return $str;
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
    my ( $self, $line, $arg_ref ) = @_;
    $self->log->trace( $self->t_as_string($arg_ref) );

    if (   !( $line =~ /^[\t]+.*$/ )
        && !( $line =~ /^[\t]*\&middot;\t.*$/ )
        && $self->currentitem ne "" )
    {
        # 1 => E1
        if ( $self->itemlevel == 2 ) {
            $line = "\\end{itemize}\n\\end{itemize}\n\n" . $line;
        }
        elsif ( $self->itemlevel == 1 ) {
            $line = "\\end{itemize}\n\n" . $line;
        }
        $self->currentitem("");
        $self->itemlevel(0);
        return $line;
    }
    elsif ( $line =~ /^[\t]+(.*)$/ ) {
        my $content = $1;
        if ( $self->itemlevel == 0 && $self->currentitem eq "" ) {
            # 2 => E2
            $content = "\\begin{itemize}\n\t\\item $content";
            $self->itemlevel(1);
            $self->currentitem("t");
        }
        elsif ( $self->itemlevel > 0 && $self->currentitem eq "t" ) {
            # 3 => E3
            if ( $self->itemlevel == 1 ) {
                $content = "\t\\item $content";
            }
            else {
                $content = "\t\t\\item $content";
            }
        }
        elsif ( $self->itemlevel == 1 && $self->currentitem eq "m" ) {
            # 4 => E4
            $self->content = "\\begin{itemize}\n\t\t\\item $content";
            $self->itemlevel(2);
            $self->currentitem("t");
        }
        elsif ( $self->itemlevel == 2 && $self->currentitem eq "m" ) {
            # 5 => E5
            $content = "\\end{itemize}\n\t\\item $content";
            $self->itemlevel(1);
            $self->currentitem("t");
        }
        $line = $content;
    }
    elsif ( $line =~ /^[\t]*\&middot;\t(.*)$/ ) {
        my $content = $1;
        if ( $self->itemlevel == 0 && $self->currentitem eq "" ) {
            # 6 => E2
            $content = "\\begin{itemize}\n\t\\item $content";
            $self->itemlevel(1);
            $self->currentitem("m");
        }
        elsif ( $self->itemlevel > 0 && $self->currentitem eq "m" ) {
            # 7 => E3
            if ( $self->itemlevel == 1 ) {
                $content = "\t\\item $content";
            }
            else {
                $content = "\t\t\\item $content";
            }
        }
        elsif ( $self->itemlevel == 1 && $self->currentitem eq "t" ) {
            # 8 => E4
            $content = "\\begin{itemize}\n\t\t\\item $content";
            $self->itemlevel(2);
            $self->currentitem("m");
        }
        elsif ( $self->itemlevel == 2 && $self->currentitem eq "t" ) {
            # 9 => E5
            $content = "\\end{itemize}\n\t\\item $content";
            $self->itemlevel(1);
            $self->currentitem("m");
        }
        $line = $content;
    }

    return $line;
}


#
# rtf2txt
#
# Convert a file from rtf to a txt string.
#
# $file     : The file to convert, w/o extension.
# returns   : The rtf content as plain text.
#
sub rtf2txt {
    my ( $self, $file, $arg_ref ) = @_;
    $self->log->trace( $self->t_as_string($arg_ref) );

    if ( -f "$file.comments" ) {
        return commentsParser($file);
    }

    my $result;
    my $rtfparser = new RTF::TEXT::Converter( output => \$result );
    $rtfparser->parse_stream("$file.rtf");
    return $result;
}


#
# commentsParser
#
# Special parsing for scrivener files that also
# have comments. If this is so, we will find:
#
# * For a file 405.rtf, there is a 405.comments
# * In 405.rtf, we will find sections such as
#   text {\field{\*\fldinst{HYPERLINK "scrivcmt://5CE6FC1A-AE63-439D-89BC-3232E9CD0478"}}{\fldrslt footnote text}} more text
# * In 405.comments we will find
#
# <Comments><Comment ID="5CE6FC1A-AE63-439D-89BC-3232E9CD0478" Footnote="Yes" Color="0.992 0.929 0.525"><![CDATA[ rtf here ]]></Comment></Comments>
#
# * There are comments, and there are footnotes
# * Footnontes have an attribute Footnote=Yes
# * Footnotes or comments never overlap.
#
# So therefore, if we come down here, we know that
# we have a .comments file. We hence are going to
# re-insert, only the footnotes, into the rtf,
# using TeXDown syntax "__ ... __". Then we will
# hand it over to RTF::TEXT::Converter, and hope
# for the best.
#
# $file     : The file to convert, w/o extension.
# returns   : The rtf content as plain text, with
#             footnotes merged back in (if any).
#
sub commentsParser {
    my ( $self, $file, $arg_ref ) = @_;
    $self->log->trace( $self->t_as_string($arg_ref) );

    #
    # Slurp in rtf
    #
    open FILE, "<$file.rtf";
    my $rtf = do { local $/; <FILE> };

    #
    # Slurp in comments
    #
    my $cmt = XML::LibXML->load_xml( location => "$file.comments" );

    #
    # Iterate footnotes
    #
    my @footnotes = $cmt->findnodes('/Comments/Comment[@Footnote="Yes"]');

    foreach my $footnote (@footnotes) {
        my $footnoteId    = $footnote->getAttribute("ID");
        my $footnoteValue = $footnote->string_value;
        my $footnotePlain;
        my $rtfparser
            = RTF::TEXT::Converter->new( output => \$footnotePlain );
        $rtfparser->parse_string($footnoteValue);

        # Remove line breaks
        $footnotePlain =~ s/\R/ /g;

#{\field{\*\fldinst{HYPERLINK "scrivcmt://5CE6FC1A-AE63-439D-89BC-3232E9CD0478"}}{\fldrslt footnote text}}

        $rtf
            =~ s!\{\\field.*?scrivcmt://$footnoteId"\}\}\{\\fldrslt (.*?)\}\}!$1__${footnotePlain}__!g;
    }

    #
    # Parse the result
    #
    my $result;
    my $rtfparser = RTF::TEXT::Converter->new( output => \$result );
    $rtfparser->parse_string($rtf);


    return $result;
}


sub describe {
    my ($self) = @_;

    return $self->{parser_of};
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe() ) } );
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
