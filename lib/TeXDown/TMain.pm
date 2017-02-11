package TeXDown::TMain;

=pod

=head1 NAME

TeXDown::TMain - Main Program Routine.

=head1 DESCRIPTION

This class provides for the main program routine of TeXDown.

You can use it like so:

    # Initialize, or rather, reuse from elsewhere...

    my $texdown = TeXDown::TMain->new;
    $texdown->run;

See L<"run"> for more description.


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
use TeXDown::Scrivener::TScrivener;


=begin testing SETUP

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
#   inline2test t/inline2test.ini
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

###################################################
#
# Test Setup
#
###################################################

my $MODULE       = 'TeXDown::TMain';

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

=end testing

=cut


=begin testing Construct

    ok( 1 == 1, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;
}


=head2 run

C<run>
main program routine.

=cut


sub run {
    my $self = shift;
    $self->log->trace( $self->t_as_string(@_) );

    #
    # Instantiate the File Resolver
    #
    my $resolver = TeXDown::TFileResolver->new;

ARG:
    foreach my $arg (@_) {
        $self->log->debug( "Start Configuration: " . pp( $::cfg->describe() ) );

        #
        # Narrow down the projects that we have got on the
        # command line. This will not yet replace any of
        # them by whatever comes from a configuration file,
        # as we did not yet load a configuration file.
        #
        my @projects
            = @{ $::cfg->get( "p", { 'as_array' => 1, 'condense' => 1 } ) };

        #
        # If we did not specify any project, let's
        # attempt to resolve the project by the file
        # name of the scriv directory.
        #
        # E.g., if we were given Dissertation as command
        # line parameter, and hence there is a Dissertation.scriv
        # directory, the project that we are trying to resolve in
        # Dissertation.scriv/Dissertation.scrivx is going to be
        # /Dissertation.
        #
        if ( @projects == 0 ) {
            my ( $d, $f, $p ) = $resolver->resolve_files($arg);

            push @projects, $p;

            $::cfg->set( "p", \@projects );
        }


        if ( -e "$arg" || -e "$arg.scriv" ) {
            my ( $dir, $file, $project ) = $resolver->resolve_files($arg);

            if ( defined($project) && $project ne "" ) {
                #
                # Scrivener
                #

                #
                # Option 1:
                #
                # - Indirect project definition by configuration file...
                # - ...but don't even say, which configuration file to use
                # - yet at least, we say which project(s) to use
                #
                # If we did have projects, and cfg set, but empty,
                # we still try to find a default configuration,
                # rather than running on the projects ourselves
                #
                # This is invoked e.g. like so:
                #
                # ./texdown.pl Dissertation -l -c -p roilr
                #
                # We are hence working on the Dissertation.scriv,
                # and we are saying we want to use a configuration
                # file, without specifying its name. Hence the
                # program will attempt to use Dissertation.cfg.
                # We also said that we want to use a given project
                # that's defined in the configuration file, in this
                # case roilr.
                #
                if (   @projects > 0
                    && $::cfg->contains_key("c")
                    && $::cfg->get("c") eq "" )
                {
                    if ( -f "$dir/../$project.ini" ) {
                        #
                        # Save configuration file setting
                        #
                        my $c_back = $::cfg->get("c");

                        $::cfg->set( "c", "$dir/../$project.ini" );

                        my $cfgvar = "";
                        my $netcfg = "";
                        if ( $::cfg->contains_key("c") && $::cfg->get("c") ne "" )
                        {
                            $::cfg->load();
                            $::cfg->set( "scriv",  $dir );
                            $::cfg->set( "scrivx", $file );
                            $cfgvar = "\nini : " . $::cfg->get("c");
                            $netcfg = "Final Configuration: "
                                . pp( $::cfg->describe() );
                        }
                        $self->log->info(
                            "[1] Running with configuration file: $cfgvar \ndir : $dir \nfile: $file"
                        );
                        $self->log->debug($netcfg) if "" ne $netcfg;

                        #runFromCfg( $dir, $file );
                        #
                        my $scrivener = $self->load_scrivx( $dir, $file );

                        $scrivener->parse();

                        #
                        # Restore configuration file setting
                        #
                        $::cfg->set( "c", $c_back );

                        next ARG;
                    }
                }

                #
                # Option 2:
                #
                # This is the standard case, without configuration file,
                # invoked e.g. like so:
                #
                # ./texdown.pl Dissertation -l -p /Trash
                #
                # We are working on Dissertation.scriv, and we say we
                # want to use a project that's actually like this available
                # in that file (we can use absolute or relative names).
                #
                my $cfgvar = "";
                my $netcfg = "";
                if ( $::cfg->contains_key("c") && $::cfg->get("c") ne "" ) {
                    $::cfg->load();
                    $::cfg->set( "scriv",  $dir );
                    $::cfg->set( "scrivx", $file );
                    $cfgvar = "configuring " . $::cfg->get("c");
                    $netcfg
                        = "Final Configuration: " . pp( $::cfg->describe() );
                }
                else {
                    $::cfg->set( "scriv",  $dir );
                    $::cfg->set( "scrivx", $file );
                    $cfgvar = "without configuration file: ";
                    $netcfg
                        = "Final Configuration: " . pp( $::cfg->describe() );
                }
                $self->log->info(
                    "[2] Running $cfgvar \ndir : $dir \nfile: $file");
                $self->log->debug($netcfg) if "" ne $netcfg;

                my $scrivener = $self->load_scrivx( $dir, $file );

                $scrivener->parse();

                #parseScrivener( $dir, $file );
            }    # if ( defined($project) && $project ne "" )
            else {
                #
                # Option 3:
                #
                # Plain Text
                #
                # ./texdown.pl document.tex
                #
                my $cfgvar = "";
                my $netcfg = "";
                if ( $::cfg->contains_key("c") && $::cfg->get("c") ne "" ) {
                    $::cfg->load();
                    $::cfg->set( "scriv",  $dir );
                    $::cfg->set( "scrivx", $file );
                    $cfgvar = "configuring " . $::cfg->get("c");
                    $netcfg
                        = "Final Configuration: " . pp( $::cfg->describe() );
                }
                else {
                    $::cfg->set( "scriv",  $dir );
                    $::cfg->set( "scrivx", $file );
                    $cfgvar = "without configuration file: ";
                    $netcfg
                        = "Final Configuration: " . pp( $::cfg->describe() );
                }
                $self->log->info(
                    "[3] Running on plain text $cfgvar \ndir : $dir \nfile: $file"
                );
                $self->log->debug($netcfg) if "" ne $netcfg;

                #parsePlain ($dir, $file);
            }
        }    # if ( -e "$arg" || -e "$arg.scriv" )
        else {
            $self->log->error("Neither $arg nor $arg.scriv found.");
        }
    }    # foreach my $arg (@_)
}

sub load_scrivx {
    my ( $self, $dir, $file, $arg_ref ) = @_;

    $self->log->trace( $self->t_as_string( $dir, $file, $arg_ref ) );

    my $scrivener = TeXDown::Scrivener::TScrivener->new;
    $scrivener->load( $dir, $file );

    return $scrivener;
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
