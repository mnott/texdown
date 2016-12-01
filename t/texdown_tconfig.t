#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
$| = 1;



# =begin testing SETUP
# Mostly dynamic construction of module path
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname( abs_path $0) . '/../lib';

binmode STDOUT, ":utf8";
use utf8;
use feature qw(say);
use Data::Dumper qw (Dumper);

use TeXDown::TConfig;

my $INI = 't/texdown-test.ini';

my $MODULE = 'TeXDown::TConfig';

my $cfg = TeXDown::TConfig->new();



# =begin testing Construct
{
    ok( defined($cfg) && ref $cfg eq $MODULE, 'Passed: new()' );
}



# =begin testing SetNew
{
    $cfg->set("a", "b");
    my $res = $cfg->get("a");
    ok( $res eq "b", 'Passed: set() - new' );
}



# =begin testing SetReplace
{
    $cfg->set("a", "b");
    $cfg->set("a", "c");
    my $res = $cfg->get("a");
    ok( $res eq "c", 'Passed: set() - replace' );
}



# =begin testing SetRemove
{
    $cfg->set("a", "b");
    $cfg->set("a", undef);
    my $res = $cfg->get("a");
    ok( !defined $res, 'Passed: set() - remove' );
}



# =begin testing SetArray
{
    my @array_in = ("b", "c");
    $cfg->set("a", \@array_in);
    my @array_out = @{ $cfg->get("a") };
    ok( @array_out == 2 && ref \@array_out eq 'ARRAY', 'Passed: set() - array' );
}




1;
