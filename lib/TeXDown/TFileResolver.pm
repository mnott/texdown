package TeXDown::TFileResolver;

=pod

=head1 NAME

TeXDown::TFileResolver - Be somewhat gentle when it comes to finding
out where the Scrivener directory is.

=head1 DESCRIPTION

This class provides for file resolving function L<resolve_files>
that resolves the location and name of a file.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...

    my $resolver = TeXDown::TFileResolver->new;

    # If we did not specify a project, let's attemt to resolve it

    my ($dir, $file, $project) = $resolver->resolve_files($dir);


See L<"resolve_files"> for more description.


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

my $MODULE       = 'TeXDown::TFileResolver';

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

our $cfg      = TeXDown::TConfig->new;

$cfg->load($INI);

my $resolver = TeXDown::TFileResolver->new;

=end testing

=cut


=begin testing Construct

    ok( defined($resolver) && ref $resolver eq $MODULE, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;
}


=head2 resolve_files

C<resolve_files>
resolves the location and name of a file. For Scrivener,
its content for a project like Dissertation is held in a
directory Dissertation.scriv, which contains, among other
things, an XML file Dissertation.scrivx. This function
will resolve the location of the Dissertation.scriv
directory, and return its directory, file/directory name,
as well as its base name (in this case: Dissertation),
for further processing.

Parameters:

    $par    : Some file name or location to resolve.

Returns:

    $dir    : The Directory of the File, e.g., Dissertation.scriv
    $file   : The Filename of the XML File, e.g., Dissertation.scriv/Dissertation.scrivx
    $project: The Scrivener Directory base name, or an empty String

=cut


sub resolve_files {
    my ( $self, $arg, $arg_ref ) = @_;
    $self->log->trace( $self->t_as_string( $arg, $arg_ref ) );

    if ( -e "$arg" || -e "$arg.scriv" ) {
        my ( $fname, $fpath, $fsuffix ) = fileparse( $arg, qr/\.[^.]*/ );
        my $basename = basename( $arg, qr/\.[^.]*/ );
        my $dirname = dirname($arg);

        #
        # If we have an $fname, it can still be a directory,
        # because Scrivener saves its files in "files," which
        # are really directories. So we have to test some cases.
        #
        if ( $fname ne "" ) {
            if ( -d "$fpath$fname.$fsuffix" ) {
                $fpath = "$fpath$fname$fsuffix";
            }
            elsif ( -d "$fpath$fname.scriv" ) {
                $fsuffix = ".scriv";
                $fpath   = "$fpath$fname$fsuffix";
            }
            else {
                $fpath = $arg;
            }
        }
        else {
            if ( -d "$fpath" ) {
                $fpath =~ s/(.*?\.scriv).*/$1/;
            }
        }

        my $found = $fpath;
        ( $fname, $fpath, $fsuffix ) = fileparse( $fpath, qr/\.[^.]*/ );

        if ( -d "$found" && -e "$found/$fname.scrivx" ) {
            my $dir  = "$found";
            my $file = "$fpath$fname.scriv/$fname.scrivx";

            return ( $dir, $file, $fname );
        }
        elsif ( -f "$found" ) {
            my $dir  = "$fpath";
            my $file = "$found";

            return ( $dir, $file, "" );
        }
    }

}


sub describe {
    my ($self) = @_;

    return $::cfg;
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe ) } );
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
