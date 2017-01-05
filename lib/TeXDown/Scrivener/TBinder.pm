package TeXDown::Scrivener::TBinder;

=pod

=head1 NAME

TeXDown::Scrivener::TBinder Hold the Binder of a Scrivx file.

=head1 DESCRIPTION

This class holds the Binder of a Scrivx file.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...; $cfg
    # would be an instance of TeXDown::TConfig

    my $parser = TeXDown::Scrivener::TBinder->new( cfg => $cfg );

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

my $cfg      = TeXDown::TConfig->new();

$cfg->load($INI);

=end testing

=cut


has cfg => (
    is   => 'rw',
    isa  => 'TeXDown::TConfig',
    lazy => 0,
);

has binderitems => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[TeXDown::Scrivener::TBinderItem]',
    default => sub { [] },
    lazy    => 0,
);

has binderitems_by_title => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[TeXDown::Scrivener::TBinderItem]]',
    default => sub { {} },
    lazy    => 0,
);


has binderitems_by_id => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[TeXDown::Scrivener::TBinderItem]',
    default => sub { {} },
    lazy    => 0,
);



=begin testing Construct

    ok( 1 == 1, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    $self->log->trace("Instantiated TBinder");
    $self->cfg( $arg_ref->{cfg} ) if exists $arg_ref->{cfg};
}

sub load {
    my ( $self, $el, $arg_ref ) = @_;
    my $cfg         = $self->cfg;
    my $binderitems = $self->binderitems;

    $self->log->trace("Loading TBinder");

    my @xml_binderitems = $el->findnodes('BinderItem');

    foreach my $xml_binderitem (@xml_binderitems) {
        my $binderitem = TeXDown::Scrivener::TBinderItem->new(
            cfg    => $cfg,
            binder => $self
        );
        $binderitem->load($xml_binderitem);
        $self->add($binderitem);
    }

    $self->log->trace( "Loaded "
            . ( scalar @$binderitems )
            . " binder items for this binder" );
}

sub add {
    my ( $self, $binderitem ) = @_;

    # $self->log->trace( "+ Adding: " . $binderitem->title );

    my $binderitems = $self->binderitems;

    push( @$binderitems, $binderitem );

    $self->track($binderitem);
}


#
# Add the shortcuts for each binder item
#
sub track {
    my ( $self, $binderitem ) = @_;
    my $binderitems = $self->binderitems;

    #
    # Track by Titles
    #
    my %htitles = %{ $self->binderitems_by_title };

    my @arr;

    if ( exists $htitles{ $binderitem->title } ) {
        @arr = @{ $htitles{ $binderitem->title } };
        push( @arr, $binderitem );
    }
    else {
        @arr = ($binderitem);
        $htitles{ $binderitem->title } = \@arr;
        $self->binderitems_by_title( \%htitles );
    }

    #
    # Track by IDs (simpler, since we assume IDs are unique)
    #
    my %hids = %{ $self->binderitems_by_id };
    $hids{ $binderitem->id } = $binderitem;
    $self->binderitems_by_id( \%hids );
}

#
# When we parse our binder, we create a new binder which will
# contain the flat list of binderitems that we will then next
# output.
#
sub parse {
    my ( $self, $arg_ref ) = @_;

    my $cfg = $self->cfg;

    $self->log->trace("> Parse process");

    my $binderitems = $self->binderitems;

    my $result = TeXDown::Scrivener::TBinder->new( cfg => $cfg );

    my @projects = @{ $cfg->get( 'p', { 'as_array' => 1 } ) };

    foreach my $project (@projects) {
        if ( $project =~ "^/.*" ) {
            #
            # Absolute location
            #
            #$self->log->trace( "+ Parsing p = " . $project );

            ## Split the path into an array
            #my @locations = t_split( "/", $project );

            #my $binderitem = $self->get_child( { title => @locations[0] } );

            #if (defined $binderitem) {

            #}

        }
        elsif ( $project =~ /^-?\d+$/ ) {
            #
            # Giving directly a project Id
            #
            #foreach my $binderItem (
            #    $doc->findnodes( '//BinderItem[@ID="' . $project . '"]' ) )
            #{
            #    printNode( $binderItem, "", 0, $dir );
            #}
        }
        else {
            #
            # Relative location; /Children/* are being resolved by recursion
            #
            my $binderitems = $self->by_title($project);

            foreach my $binderitem (@$binderitems) {
                $binderitem->print(
                    {   parent => $binderitem,
                        path   => "",
                        level  => 0,
                    }

                );
            }


            #foreach my $binderItem (
            #    $doc->findnodes(
            #        '//BinderItem[Title/text() = "' . "$project" . '"]'
            #    )
            #    )
            #{
            #    printNode( $binderItem, "", 0, $dir );
            #}
        }
    }


    $self->log->trace("< Parse process");
}

sub by_title {
    my ( $self, $title ) = @_;

    my %htitles = %{ $self->binderitems_by_title };

    my @arr;

    if ( exists $htitles{$title} ) {
        @arr = @{ $htitles{$title} };
    }

    return \@arr;
}


sub get_child {
    my ( $self, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    my $what = "";
    my $id;
    my $title;
    my $uuid;

    if ( exists $arg_ref->{'id'} ) {
        $id   = $arg_ref->{'id'};
        $what = $id;
        $self->log->trace("> get_child (by id): $what");
    }
    elsif ( exists $arg_ref->{'title'} ) {
        $title = $arg_ref->{'title'};
        $what  = $title;
        $self->log->trace("> get_child (by title): $what");
    }
    elsif ( exists $arg_ref->{'uuid'} ) {
        $uuid = $arg_ref->{'uuid'};
        $what = $uuid;
        $self->log->trace("> get_child (by uuid): $what");
    }


    my $binderitems = $self->binderitems;



    foreach my $binderitem (@$binderitems) {
        if ($id) {
            if ( $id == $binderitem->id ) {
                $self->log->trace("< get_child: $what");
                return $binderitem;
            }
        }
        elsif ($title) {
            if ( $title eq $binderitem->title ) {
                $self->log->trace("< get_child: $what");
                return $binderitem;
            }
        }
        elsif ($uuid) {
            if ( $uuid eq $binderitem->uuid ) {
                $self->log->trace("< get_child: $what");
                return $binderitem;
            }
        }
        else {
            $self->log->error("< get_child: where you looking for? ($what)");
            return undef;
        }

    }

    $self->log->trace("< get_child: $what not found.");
    return undef;
}





sub describe {
    my ($self) = @_;

    return $self->binderitems;
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe() ) } );
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
