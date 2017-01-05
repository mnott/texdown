package TeXDown::Scrivener::TBinderItem;

=pod

=head1 NAME

TeXDown::Scrivener::TBinderItem Hold the BinderItem of a Scrivx file.

=head1 DESCRIPTION

This class holds the BinderItem of a Scrivx file.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...; $cfg
    # would be an instance of TeXDown::TConfig

    my $parser = TeXDown::Scrivener::TBinderItem->new( cfg => $cfg, binder => $self );

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

use Moose;
with 'MooseX::Log::Log4perl';

use namespace::autoclean -except => sub { $_ =~ m{^t_.*} };

use TeXDown::TConfig;
use TeXDown::TUtils qw/ t_as_string /;
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

my $cfg      = TeXDown::TConfig->new();

$cfg->load($INI);

=end testing

=cut


has cfg => (
    is   => 'rw',
    isa  => 'TeXDown::TConfig',
    lazy => 0,
);

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
    isa => 'Int',
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
    $self->cfg( $arg_ref->{cfg} ) if exists $arg_ref->{cfg};


    if ( exists $arg_ref->{level} ) {
        $self->level( $arg_ref->{level} );
    }
    else {
        $self->level(1);
    }
}

sub load {
    my ( $self, $el ) = @_;
    my $level       = $self->level;
    my $binderitems = $self->binderitems;

    my $id       = $el->getAttribute("ID");
    my $title    = $el->find("Title")->to_literal->value;
    my $uuid     = $el->getAttribute("UUID");
    my $type     = $el->getAttribute("Type");
    my $metadata = $el->findnodes("MetaData")->[0];
    my $inc      = $metadata->find("IncludeInCompile")->to_literal->value;

    $self->id($id);
    $self->title($title);
    $self->uuid($uuid);
    $self->type($type);
    $self->inc( "Yes" eq $inc );

    my $indent = "  " x $level;

    my $logline = sprintf( "%s [%5d] %s ", $indent, $id, $title );

    my @xml_binderitems = $el->findnodes('Children/BinderItem');

    $self->log->trace($logline);

    foreach my $xml_binderitem (@xml_binderitems) {
        my $binderitem = TeXDown::Scrivener::TBinderItem->new(
            cfg    => $self->cfg,
            level  => ++$level,
            binder => $self->binder,
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
    my $dir    = $self->cfg->get("dir");

    $self->log->trace("+ Print: " . $parent->title);

    my $parentTitle = "$path/" . $parent->title;
    my $docId       = $parent->id;
    my $docType     = $parent->type;
    my $docTitle    = $parent->title;
    my $inc         = $parent->inc;

    my $all  = $self->cfg->get("all");
    my $list = $self->cfg->get("l");

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
            my $printline = sprintf( "[%8d] %s", $docId, $parentTitle );

            print "$printline\n";
        }
        else {
            $self->log->trace("We will be printing content here.");

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
