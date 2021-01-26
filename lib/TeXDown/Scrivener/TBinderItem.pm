package TeXDown::Scrivener::TBinderItem;

=pod

=head1 NAME

TeXDown::Scrivener::TBinderItem Hold the BinderItem of a Scrivx file.

=head1 DESCRIPTION

This class holds the BinderItem of a Scrivx file.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...

    my $parser = TeXDown::Scrivener::TBinderItem->new( binder => $self );

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

use XML::LibXML;
use Term::ANSIColor qw( colored );

use Moose;
with 'MooseX::Log::Log4perl';

use namespace::autoclean -except => sub { $_ =~ m{^t_.*} };

use TeXDown::TConfig;
use TeXDown::TUtils qw/ t_as_string t_split /;
use TeXDown::Scrivener::TBinderItem;


=begin testing SETUP

###################################################
#
# Test Setup
#
###################################################

my $MODULE       = 'TeXDown::Scrivner::TBinder';

my @DEPENDENCIES = qw / TeXDown::Scrivener::TBinderItem
                        TeXDown::TConfig
                        TeXDown::TUtils
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

our $cfg      = TeXDown::TConfig->new;

$cfg->load($INI);

=end testing

=cut

has binder => (
    is   => 'rw',
    isa  => 'TeXDown::Scrivener::TBinder',
    lazy => 0,
);

has binderitems => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[TeXDown::Scrivener::TBinderItem]',
    default => sub { [] },
    lazy    => 0,
);

has level => (
    is  => 'rw',
    isa => 'Int',
);

has id => (
    is  => 'rw',
    isa => 'Str',
);


has path => (
    is  => 'rw',
    isa => 'Str',
);

has title => (
    is  => 'rw',
    isa => 'Str',
);

has uuid => (
    is  => 'rw',
    isa => 'Str',
);

has inc => (
    is  => 'rw',
    isa => 'Bool',
);

has type => (
    is  => 'rw',
    isa => 'Str',
);



=begin testing Construct

    ok( 1 == 1, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;

    if ( exists $arg_ref->{level} ) {
        $self->level( $arg_ref->{level} );
    }
    else {
        $self->level(1);
    }

    if ( exists $arg_ref->{path} ) {
        $self->path( $arg_ref->{path} );
    }
    else {
        $self->path("");
    }
}

sub load {
    my ( $self, $el ) = @_;
    my $level       = $self->level;
    my $binderitems = $self->binderitems;

    my $id
        = defined $::cfg->get("2")
        ? $el->getAttribute("ID")
        : $el->getAttribute("UUID");

    my $title    = $el->find("Title")->to_literal->value;
    my $uuid     = $el->getAttribute("UUID");
    my $type     = $el->getAttribute("Type");
    my $metadata = $el->findnodes("MetaData")->[0];

    my $inc;
    if ( defined $::cfg->get("2") ) {
        $inc
            = ( defined $metadata )
            ? $metadata->find("IncludeInCompile")->to_literal->value
            : "Yes";
    }
    else {
        $inc
            = ( defined $metadata )
            ? $metadata->find("IncludeInCompile")->to_literal->value
            : "No";
    }

    $self->id($id);
    $self->title($title);
    $self->uuid($uuid);
    $self->type($type);
    $self->inc( "Yes" eq $inc );
    $self->path( $self->path . "/" . $self->title );

    my $indent = "  " x $level;

    my $logline = sprintf( "%s [%s] %s ", $indent, $id, $title );

    my @xml_binderitems = $el->findnodes('Children/BinderItem');

    $self->log->trace($logline);

    foreach my $xml_binderitem (@xml_binderitems) {
        my $binderitem = TeXDown::Scrivener::TBinderItem->new(
            level  => ++$level,
            binder => $self->binder,
            path   => $self->path,
        );
        $binderitem->load($xml_binderitem);
        $self->add($binderitem);
    }

#$self->log->trace( "Loaded " . $id . $indent . $title . "(" . (scalar @xml_binderitems) . " children)");
}

sub add {
    my ( $self, $binderitem ) = @_;

    push( @{ $self->binderitems }, $binderitem );

    $self->binder->track($binderitem);
}


#
# print
#
# Recursive Function to conditionally print an dive into children
#
sub print {
    my ( $self, $arg_ref ) = @_;

    my $parent = $arg_ref->{parent};
    my $path   = $arg_ref->{path};
    my $level  = $arg_ref->{level};
    my $dir    = $::cfg->get("scriv");

    $self->log->trace( "+ Print: " . $parent->title );

    my $parentTitle = "$path/" . $parent->title;
    my $docId       = $parent->id;
    my $docType     = $parent->type;
    my $docTitle    = $parent->title;
    my $inc         = $parent->inc;

    my $all       = $::cfg->get("a");
    my $list      = $::cfg->get("l");
    my $debug     = $::cfg->get("v");
    my $search    = $::cfg->get("s");
    my $dontparse = $::cfg->get("n");
    my $parser    = $::parser;

    #
    # If we are restricting by the Scrivener metadata field
    # IncludeInCompile (which we do by default), then if a
    # given node has that field unchecked, we don't print
    # that node, and we don't dive into it's children.
    #
    return if ( !$all && !$inc );

    #
    # If the current node is a text node, we have to print it
    #
    if ( $docType eq "Text" ) {
        if ($list) {
            if ( defined $search ) {
                if ( $parentTitle =~ m/(.*)($search)(.*)/mi ) {
                    my $printline = sprintf( "[%s] %s: %s%s",
                        $docId,
                        colored( $1, 'green' ),
                        colored( $2, 'red' ),
                        colored( $3, 'green' ) );
                    print "$printline\n";
                }
            }
            else {
                my $printline = sprintf( "[%s] %s", $docId, $parentTitle );

                print "$printline\n";
            }
        }
        else {
            my $rtf
                = defined $::cfg->get("2")
                ? "$dir/Files/Docs/$docId.rtf"
                : "$dir/Files/Data/$docId/content.rtf";

            if ( -e "$rtf" ) {
                my $line = "";
                if ($debug) {
                    $line
                        = "\n\n<!--\n%\n%\n% "
                        . $docId . " -> "
                        . $docTitle
                        . "\n%\n%\n-->\n";
                }

                my $curline
                    = defined $::cfg->get("2")
                    ? $parser->rtf2txt("$dir/Files/Docs/$docId")
                    : $parser->rtf2txt("$dir/Files/Data/$docId/content");

                #
                # If we are asked to search for something, we intepret the
                # search string as (potential) regex, and search the files,
                # but don't do anything else.
                #
                if ( defined $search ) {
                    $curline = $parser->parse($curline) unless $dontparse;

                    my @lines = t_split( "\n", $curline );
                    foreach my $aline (@lines) {
                        if ( $aline =~ m/(.{0,30})($search)(.{0,30})/mi ) {
                            my $printline = sprintf( "[%s] %s: %s%s%s",
                                $docId,
                                $parentTitle,
                                colored( $1, 'green' ),
                                colored( $2, 'red' ),
                                colored( $3, 'green' ) );
                            print "$printline\n";
                        }
                    }
                }
                else {
                    $line .= $curline;

                    $line = $parser->parse($line) unless $dontparse;
                    if (defined $line) { print "$line\n" };
                }
            }


        }
    }


    #
    # If the current node has children, we need to call them (and let
    # them decide whether they want to process themselves)
    #
    my $binderitems = $self->binderitems;

    foreach my $binderitem (@$binderitems) {
        $binderitem->print(
            {   parent => $binderitem,
                path   => $parentTitle,
                level  => ++$level,
            }
        );
    }
}


sub get_child {
    my ( $self, $title ) = @_;
    my $binderitems = $self->binderitems;

    foreach my $binderitem (@$binderitems) {
        if ( $binderitem->title eq $title ) {
            return $binderitem;
        }
    }
    return 0;
}


sub size {
    my ($self) = @_;

    return scalar @{ $self->binderitems };
}


sub describe {
    my ($self) = @_;

    return $self->binderitems;
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe ) } );
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
