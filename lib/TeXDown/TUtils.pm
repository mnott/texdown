package TeXDown::TUtils;

=pod

=head1 NAME

TeXDown::Utils - Shared Utilities

=head1 DESCRIPTION

This class provides for some utility functions shared elsewhere.


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


=begin testing SETUP

###################################################
#
# Test Setup
#
###################################################

my $MODULE       = 'TeXDown::TUtils';

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

ok (1 == 1, 'Passed: Construct');

=end testing

=cut


use Exporter 'import';
use XML::LibXML;
use XML::LibXML::PrettyPrint;

our @EXPORT_OK = qw/ t_as_string /;

sub t_as_string {
    my $self = shift;
    my $res  = "";
    my $pp   = XML::LibXML::PrettyPrint->new( indent_string => "  " );

    foreach my $arg (@_) {
        if ( !defined $arg ) {
            $res .= "";
        }
        else {
            if ( $res ne "" ) {
                $res .= ", ";
            }
            $res .= pp($arg);
        }
    }
    return $res;
}



1;
