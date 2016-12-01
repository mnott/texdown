#!/usr/bin/env perl -w
###################################################
#
# About the documentation:
#
# Created like
#
# pod2markdown.pl <texdown.pl >README.md
#
# Using the excellent podmarkdown by Randy Stauner.
#
###################################################


my $pod2md = "pod2markdown.pl";    # Must be in $PATH

=head1 NAME

TeXDown - Markdown for LaTeX and Instrument Scrivener

=head1 VERSION

Version 0.0.1ch

=head1 LICENCE AND COPYRIGHT
Copyright (c) 2016 Matthias Nott (mnott (at) mnsoft.org).

Licensed under WTFPL.

=cut

###################################################
#
# Dependencies
#
###################################################

=head1 DEPENDENCIES

=cut

use strict;
use warnings;

binmode STDOUT, ":utf8";
use utf8;
use Carp qw(carp cluck croak confess);
use feature qw(say);
use Data::Dumper qw (Dumper);
use Pod::Usage;
use Try::Tiny;

###################################################
#
# Relative Library Directory Lookup
#
###################################################

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname( abs_path $0) . '/lib';

#use TeXDown::Config;
use TeXDown::EpicConfig;

###################################################
#
# Parse the Command Line.
#
# - Uses TeXDown::Config
# - Exposes variables as $cfg->get("x") etc.
#   (which can be arrays, depending on how they
#   have been filled through GetOptions). In any
#   case, they can always be iterated either as
#   array or retrieved as single value.
#
###################################################

use Config::Simple;
use Getopt::Long;

#my $cfg = TeXDown::Config->new( { ini => 'Dissertation.ini' } );
my $cfg = TeXDown::EpicConfig->new();

GetOptions(
    'c|cfg:s'           => sub { $cfg->set(@_); },
    'h|?|help'          => sub { $cfg->set(@_); },
    'man'               => sub { $cfg->set(@_); },
    'i|id:s{,}'         => sub { $cfg->set(@_); },
    'l|list'            => sub { $cfg->set(@_); },
    'p|project:s{,}'    => sub { $cfg->set(@_); },
    's|search:s'        => sub { $cfg->set(@_); },
    'doc|documentation' => sub { $cfg->set(@_); },
    'parser:s'          => sub { $cfg->set(@_); },
) or pod2usage(2);
#pod2usage(1) if $cfg->is("h");
#pod2usage( -exitval => 0, -verbose => 2 ) if $cfg->is("m");





#
#my $scalar = "a";
#my @array = ("x", "y");

#$cfg->set("sscalar", $scalar);    # scalar
#$cfg->set("ascalar", $scalar);    # scalar
#$cfg->set("hscalar", $scalar);    # scalar
#$cfg->set("sarray", \@array);     # full @array
#$cfg->set("aarray", \@array);     # full @array
#$cfg->set("harray", \@array);     # full @array
#$cfg->set("shash", \%hash);       # full %hash
#$cfg->set("hhash", \%hash);       # full %hash


#my $rsscalar = $cfg->get("sscalar"); # ok: scalar
#my @rascalar = $cfg->get("ascalar"); # ok: scalar in array
#my %rhscalar = $cfg->get("hscalar"); # ok: scalar => undef
#
#my $rsarray = $cfg->get("sarray"); # ok: array size
#my @raarray = $cfg->get("aarray"); # ok: array *
#my %rharray = $cfg->get("harray"); # ok: hash with a1 => a2, a3 => a4... *


# Working with Hashes
my %hash = ("r" => "s", "u" => "v");#, "m" => "n");
#print "ahash: " . Dumper %hash;

# Set: store reference \%hash
$cfg->set("hash", \%hash);       # full %hash

# Get: Either dereference immediately:
#my %dhash = $$cfg->get("hash");
#print "dhash: ". Dumper %dhash;

#      Or later:
my %shash = $cfg->get("hash");
#print "shash: " . Dumper %shash;

#print $shash{"r"};


#      Or later:
#my $shash = $cfg->get("ahash");
#print "shash: " . Dumper $shash;

#my %rhash = %$shash;
#print "rhash: " . Dumper %rhash;


say "done.";
 
#my $hshash = $cfg->get("shash"); # ok: hash size
#my @hahash = $cfg->get("ahash"); # ok: array with k1, v1, k2, v2...
#my %hhhash = %{$cfg->get("hhash")}; # ok: hash

#say "Now doing something";

#say Dumper %hash;
#my %htest = %$hshash;
#my @atest = @{$hshash};

#say Dumper %htest;
#say Dumper @atest;

#print $htest{"r"};
#
#print $dhshash{"r"};


exit 0;





























###################################################
#
# Documentation
#
###################################################

__END__

