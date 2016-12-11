package TeXDown::TFileResolver;

=pod

=head1 NAME

TeXDown::FileResolver - Be somewhat gentle when it comes to finding
out where the Scrivener directory is.

=head1 DESCRIPTION

This class provides for file resolving function L<resolve_files>
that resolves the location and name of a file.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...; $cfg
    # would be an instance of TeXDown::TConfig

    my $resolver = TeXDown::FileResolver->new( cfg => $cfg );

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
use Pod::Usage;
use File::Basename;
use Try::Tiny;

use Moose;
with 'MooseX::Log::Log4perl';

use namespace::autoclean -except => sub { $_ =~ m{^t_.*} };

use TeXDown::TConfig;
use TeXDown::TUtils qw/ t_as_string /;


###################################################
#
# Configure Testing here
#
# This is going to be put at the top of the test
# script. Make sure it contains all dependencies
# that are in the above use section, and that are
# relevant for testing.
#
# To generate the tests, run, from the main
# directory
#
#   inline2test t/inline2test.cfg
#
# Then test like
#
#   Concise mode:
#
#   prove -l
#
#   Verbose mode:
#
#   prove -lv
#
###################################################

=begin testing SETUP

# Mostly dynamic construction of module path
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname( abs_path $0) . '/../lib';

binmode STDOUT, ":utf8";
use utf8;
use feature qw(say);
use Data::Dumper qw (Dumper);

use TeXDown::TConfig;
use TeXDown::TFileResolver;

my $INI      = 't/texdown-test.ini';

my $MODULE   = 'TeXDown::TFileResolver';

my $cfg      = TeXDown::TConfig->new();
my $resolver = TeXDown::TFileResolver->new ( cfg => $cfg );

=end testing

=cut


has cfg_of => (
    is   => 'ro',
    isa  => 'TeXDown::TConfig',
    lazy => 0,
);


=begin testing Construct

    ok( defined($resolver) && ref $resolver eq $MODULE, 'Passed: Construct' );

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

    my $cfg = $self->{cfg_of};

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

    return $self->{cfg_of};
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe() ) } );
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
