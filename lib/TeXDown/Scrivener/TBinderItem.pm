package TeXDown::Scrivener::TBinderItem;

=pod

=head1 NAME

TeXDown::Scrivener::TBinderItem Hold the BinderItem of a Scrivx file.

=head1 DESCRIPTION

This class holds the BinderItem of a Scrivx file.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...; $cfg
    # would be an instance of TeXDown::TConfig

    my $parser = TeXDown::Scrivener::TBinderItem->new( cfg => $cfg );

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


has cfg_of => (
    is   => 'rw',
    isa  => 'TeXDown::TConfig',
    lazy => 0,
);

has binderitems_of => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[TeXDown::Scrivener::TBinderItem]',
    default => sub { [] },
    lazy    => 0,
);

has level_of => (
    is  => 'rw',
    isa => 'Int',
);




=begin testing Construct

    ok( 1 == 1, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    $self->cfg_of( $arg_ref->{cfg} ) if exists $arg_ref->{cfg};


    if ( exists $arg_ref->{level} ) {
        $self->level_of( $arg_ref->{level} );
    }
    else {
        $self->level_of(1);
    }

}

sub load {
    my ( $self, $el, $arg_ref ) = @_;
    my $cfg         = $self->cfg_of;
    my $level       = $self->level_of;
    my $binderitems = $self->binderitems_of;

    my $id    = $el->getAttribute("ID");
    my $title = $el->find("Title")->to_literal->value;

    my $indent = "  " x $level;

    my $logline = sprintf( "%s [%5d] %s ", $indent, $id, $title );

    my @xml_binderitems = $el->findnodes('Children/BinderItem');

    $self->log->trace($logline);

    foreach my $xml_binderitem (@xml_binderitems) {
        my $binderitem = TeXDown::Scrivener::TBinderItem->new(
            cfg   => $cfg,
            level => ++$level
        );
        $binderitem->load($xml_binderitem);
        push( @$binderitems, $binderitem );
    }

#$self->log->trace( "Loaded " . $id . $indent . $title . "(" . (scalar @xml_binderitems) . " children)");
}






sub describe {
    my ($self) = @_;

    return $self->binderitems_of;
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe ) } );
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
