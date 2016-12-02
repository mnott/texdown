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
    ok( defined($cfg) && ref $cfg eq $MODULE, 'Passed: Construct' );
}



# =begin testing SetNew
{
    $cfg->clear();             # Assume we did TeXDown::TConfig->new();

    $cfg->set("a", "b");
    my $res = $cfg->get("a");  # "b"

    ok( $res eq "b", 'Passed: set() - Set - New' );
}



# =begin testing SetReplace
{
    $cfg->clear();
    $cfg->set("a", "b");
    $cfg->set("a", "c");
    my $res = $cfg->get("a");  # "c"

    ok( $res eq "c", 'Passed: set() - Set - Replace' );
}



# =begin testing SetRemove
{
    $cfg->clear();
    $cfg->set("a", "b");
    $cfg->set("a", undef);
    my $res = $cfg->get("a");  # undef (a was removed)

    ok( !defined $res, 'Passed: set() - Set - Remove' );
}



# =begin testing SetArray
{
    $cfg->clear();

    my $a = [ "b", "c" ];
    my @b = ( "b", "c" );

    $cfg->set("a",  $a);
    $cfg->set("b", \@b);

    my $ar = $cfg->get("a");
    my $br = $cfg->get("b");

    ok ( ref $ar eq 'ARRAY'
      && ref $br eq 'ARRAY',
         'Passed: set() - Set - Array'
    );
}



# =begin testing SetHash
{
    $cfg->clear();

    my $a = { "b" => "c" };
    my %b = ( "d" => "e" );

    $cfg->set("a",  $a);
    $cfg->set("b", \%b);

    my $ar = $cfg->get("a");
    my $br = $cfg->get("b");

    ok ( ref $ar eq 'HASH'
      && ref $br eq 'HASH',
         'Passed: set() - Set - Hash'
    );
}



# =begin testing SetReference
{
    $cfg->clear();

    $cfg->set("a", [ "b",   "c" ] );
    $cfg->set("b", { "b" => "c" } );

    my $ar = $cfg->get("a");   # reference to [ "b",   "c" ]
    my $hr = $cfg->get("b");   # reference to { "b" => "c" }

    # Later...

    my @a  = @$ar;
    my %h  = %$hr;

    ok ( ref \@a eq 'ARRAY'
      && ref \%h eq 'HASH',
         'Passed: set() - Set - Reference'
    );
}



# =begin testing AppendNewItem
{
    $cfg->clear();

    # Set something by always using append...
    $cfg->append("a", "b");       # "a" is now a scalar "b"

    $cfg->append("a", "c");       # "a" is now an array ["b", "c"]

    # Later...

    my $content = $cfg->get("a"); # Is it now a scalar or an array?

    # Need to test defensively:
    my $must_scalar = ref $content eq 'ARRAY' ?   $content->[0] :  $content;
    my @maybe_multi = ref $content eq 'ARRAY' ? @{$content}     : ($content);

    ok ( $must_scalar eq "b",
         'Passed: append() - Append - NewItem - Still Scalar');

    ok ( ref \@maybe_multi eq 'ARRAY'
      && @maybe_multi == 2,
         'Passed: append() - Append - NewItem - Now Array');
}



# =begin testing AppendNonArrayToNonArray
{
    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", "c");
    my $res = $cfg->get("a");  # ["a", "b"]
    my @arr = @$res;           # or shorthand my @arr = @{ $cfg->get("a") }

    ok( @$res == 2
     && ref $res eq 'ARRAY'
     && @arr  == 2
     && ref \@arr eq 'ARRAY',
       'Passed: append() - Append - NonArrayToNonArray' );
}



# =begin testing AppendArrayToNonArray
{
    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", ["c", "d"]);
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d"]

    ok( @res == 3
     && ref \@res eq 'ARRAY',
       'Passed: append() - Append - ArrayToNonArray' );
}



# =begin testing AppendNonArrayToArray
{
    $cfg->clear();

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", "d");
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d"]

    ok( @res == 3
     && ref \@res eq 'ARRAY',
        'Passed: append() - Append - NonArrayToArray' );
}



# =begin testing AppendArrayToArray
{
    $cfg->clear();

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", ["d", "e"]);
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d", "e"]

    ok( @res == 4
     && ref \@res eq 'ARRAY',
        'Passed: append() - Append - ArrayToArray' );
}



# =begin testing AppendNonHashToHash
{
    $cfg->clear();

    # Set a hash:

    my %hash_in = ("b" => "c");

    $cfg->set("a", \%hash_in);

    # Later...

    $cfg->append("a", "d");                 # => Probably not what you want:

    my @array_out = @{ $cfg->get("a") };    # [ {'b' => 'c'}, 'd' ]

    ok( ref \@array_out eq 'ARRAY'
     && @array_out == 2,
        'Passed: append() - Append - NonHashToHash - Unnamed' );

    # So let's do it right...

    $cfg->clear();
    $cfg->set("a", \%hash_in);
    $cfg->append("a", "d", "e");            # <= Give it a name - here: "e"

    my %hash_out = %{ $cfg->get("a") };     # {'b' => 'c', 'e' => 'd'}

    ok( ref \%hash_out eq 'HASH'
     && keys %hash_out == 2,
        'Passed: append() - Append - NonHashToHash - Named' );
}



# =begin testing AppendHashToHash
{
    $cfg->clear();

    # Set a hash:

    my %hash_ina = ("b" => "c", "d" => "e");
    my %hash_inb = ("d" => "f", "g" => "h");

    $cfg->set("a", \%hash_ina);
    $cfg->append("a", \%hash_inb);

    my %hash_out = %{ $cfg->get("a") };   # {'b' => 'c', 'd' => 'f', 'g' => 'h'}

    ok( ref \%hash_out eq 'HASH'
     && keys %hash_out == 3,
        'Passed: append() - Append - HashToHash' );
}



# =begin testing AdvancedArrayIntoHash
{
    $cfg->clear();

    # Set a hash:

    my %hash_ina = ("b" => "c", "d" => "e");
    my %hash_inb = ("d" => ["x", "y"], "g" => "h");

    $cfg->set("a", \%hash_ina);
    $cfg->append("a", \%hash_inb);

    my %hash_out = %{ $cfg->get("a") };   # {'b' => 'c', 'd' => ["x", "y"], 'g' => 'h'}

    ok( ref \%hash_out eq 'HASH'
     && keys %hash_out == 3
     && ref ${\%hash_out{'d'}} eq 'ARRAY',
     'Passed: append() - Advanced - ArrayIntoHash' );
}



# =begin testing AdvancedRemoveInsideHash
{
    $cfg->clear();

    # Set a hash:

    my %hash_ina = ("b" => "c", "d" => "e");
    my %hash_inb = ("d" => ["x", "y"], "g" => "h");

    $cfg->set("a", \%hash_ina);
    $cfg->append("a", \%hash_inb);
    $cfg->append("a", undef, "d");

    my %hash_out = %{ $cfg->get("a") };   # {'b' => 'c', 'g' => 'h'}

    ok( ref \%hash_out eq 'HASH'
     && keys %hash_out == 2,
        'Passed: append() - Advanced - RemoveInsideHash' );
}



# =begin testing AdvancedAddSameEntry
{
    $cfg->clear();

    # Set a hash:

    my $hashref_ai = {"b" => "c", "d" => "e"};

    $cfg->set("a", $hashref_ai);

    my $hashref_bi = $cfg->get("a");   # <= Same as %hashref_ai
    $cfg->set("b", $hashref_bi);       # <= Now twice in $cfg

    $hashref_bi->{"d"} = "f";          # <= modifies both

    my $hashref_ao = $cfg->get("a");   # <= get it back from under "a"
    my $hashref_bo = $cfg->get("b");   # <= get it back from under "b"

    my $item_ai = $hashref_ai->{"d"};  # f
    my $item_ao = $hashref_ao->{"d"};  # f
    my $item_bi = $hashref_bi->{"d"};  # f
    my $item_bo = $hashref_bo->{"d"};  # f

    ok ($item_ai eq "f" &&
        $item_ao eq "f" &&
        $item_bi eq "f" &&
        $item_bo eq "f",
        'Passed: append() - Advanced - AddSameEntry');
}



# =begin testing GetHashAsArray
{
    $cfg->clear();

    # Set a hash:

    my %h = ("b" => "c", "d" => "e");

    $cfg->set("a", \%h);

    my @a = %{ $cfg->get("a") };       # [ "b", "c", "d", "e" ] or
                                       # [ "d", "e", "b", "c" ]

    ok( ( $a[0] eq "b" && $a[1] eq "c" && $a[2] eq "d" && $a[3] eq "e" )
     || ( $a[2] eq "b" && $a[3] eq "c" && $a[0] eq "d" && $a[1] eq "e" ),
        'Passed: append() - Advanced - GetHashAsArray');
}



# =begin testing GetAsArray
{
    $cfg->clear();

    $cfg->set("a", "b");

    my @aa = @{ $cfg->get("a", { 'as_array' => 1 }) }; # [ b ]
    my $sa =    $cfg->get("a");                        #  "b"

    $cfg->append("a", "c");

    my @ab = @{ $cfg->get("a") }; # <= [ "b", "c" ] (anyway array)
    my $sb =    $cfg->get("a");   # <= array ref

    ok( ref \@aa eq 'ARRAY'
     && ref \@aa eq 'ARRAY'
     && ref  $sa eq ''
     && ref  $sb eq 'ARRAY',
     'Passed: get() - GetAsArray');
}




1;
