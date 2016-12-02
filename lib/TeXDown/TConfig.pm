package TeXDown::TConfig;

=pod

=head1 NAME

TeXDown::TConfig - Read and hold shared configuration information

=head1 DESCRIPTION

This class provides for a shared place where all command line
parameters, optionally ini file content, as well as runtime
configuration is stored. Think of it as a Session where you
can put your attributes like so:

    # Initialize, or rather, reuse from elsewhere...
    my $cfg = TeXDown::TConfig->new();

    # Set something...

    $cfg->set("something", "This is something I need later");

    # Later...
    my $content = $cfg->get("something");


On top of a traditional hash, C<TConfig> provides for convenience
methods, particularly when it comes to adding content to it. While
it will never modify the content that you set into it - i.e., it
will return what you set - you do have the option to add data at a
later point in time. So, for example, continuing the previous
example, you may want to add some more data:

    $cfg->append("something", "some more data");

    # Later...
    my @array = @$cfg->get("something");

See L<"set"> for rules on setting content, and see L<"append"> for
more options when appending.


=head1 METHODS

=cut



use warnings;
use strict;

#use version; our $VERSION = qv('0.0.3');

binmode STDOUT, ":utf8";
use utf8;
use Carp qw(carp cluck croak confess);
use feature qw(say);
use Data::Dumper qw (Dumper);
use Pod::Usage;
use Config::Simple;
use Try::Tiny;

use Moose;

use namespace::autoclean;

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

my $INI = 't/texdown-test.ini';

my $MODULE = 'TeXDown::TConfig';

my $cfg = TeXDown::TConfig->new();

=end testing

=cut



has cfg_of => (
    is      => 'ro',
    traits  => ['Hash'],
    isa     => 'HashRef',
    lazy    => 0,
    default => sub { {} },
);



=begin testing Construct

    ok( defined($cfg) && ref $cfg eq $MODULE, 'Passed: Construct' );

=end testing

=cut

sub BUILD {
    my ( $self, $arg_ref ) = @_;

    # If we have been given an ini file, we load it immediately
    if ( exists $arg_ref->{ini} ) {
        $self->load( $arg_ref->{ini} );
    }

}


=head2 set

C<set> adds a new item to the hash, potentially replacing
what was there before. Setting an item to C<undef> will remove
the item.

Here are the rules:

=over

=item I<Set>

    $cfg->clear();             # Assume we did TeXDown::TConfig->new();
    $cfg->set("a", "b");
    my $res = $cfg->get("a");  # "b"

=begin testing SetNew

    $cfg->clear();             # Assume we did TeXDown::TConfig->new();

    $cfg->set("a", "b");
    my $res = $cfg->get("a");  # "b"

    ok( $res eq "b", 'Passed: set() - Set - New' );

=end testing


=item I<Replace>

    $cfg->clear();
    $cfg->set("a", "b");
    $cfg->set("a", "c");
    my $res = $cfg->get("a");  # "c"

=begin testing SetReplace

    $cfg->clear();
    $cfg->set("a", "b");
    $cfg->set("a", "c");
    my $res = $cfg->get("a");  # "c"

    ok( $res eq "c", 'Passed: set() - Set - Replace' );

=end testing


=item I<Remove>

    $cfg->clear();
    $cfg->set("a", "b");
    $cfg->set("a", undef);
    my $res = $cfg->get("a");  # undef (a was removed)

=begin testing SetRemove

    $cfg->clear();
    $cfg->set("a", "b");
    $cfg->set("a", undef);
    my $res = $cfg->get("a");  # undef (a was removed)

    ok( !defined $res, 'Passed: set() - Set - Remove' );

=end testing

=back

When setting a non scalar, just remember to pass it as
a reference, otherwise you would be passing only the
first element. You'll get back a reference.

Example:

    # Set and get an array (reference):

    $cfg->clear();

    my $a = [ "b", "c" ];
    my @b = ( "b", "c" );

    $cfg->set("a",  $a);
    $cfg->set("b", \@b);

    my $ar = $cfg->get("a");
    my $br = $cfg->get("b");

=begin testing SetArray

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

=end testing

    # Set and get a hash (reference):

    $cfg->clear();

    my $a = { "b" => "c" };
    my %b = ( "b" => "c" );

    $cfg->set("a",  $a);
    $cfg->set("b", \%b);

    my $ar = $cfg->get("a");
    my $br = $cfg->get("b");

=begin testing SetHash

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

=end testing

In the following discussion, whenever I say C<scalar>, you
an also use the same for any reference. Depending on your
application, you can of course derefence later.

Example:

    $cfg->clear();

    $cfg->set("a", [ "b",   "c" ] );
    $cfg->set("b", { "b" => "c" } );

    my $ar = $cfg->get("a");   # reference to [ "b",   "c" ]
    my $hr = $cfg->get("b");   # reference to { "b" => "c" }

    # Later...

    my @a  = @$ar;
    my %h  = %$hr;


=begin testing SetReference

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

=end testing

=cut

sub set {
    my ( $self, $var, $val, $arg_ref ) = @_;
    my $cfg = $self->{cfg_of};

    # If we have an ini file, we load it immediately
    #
    # TODO: We might think about using append here etc.
    #       at some point.
    if ( $var eq "c" ) {
        $self->load($val);
        return;
    }

    if ( exists $cfg->{$var} && !defined $val ) {
        # Setting undef removes the value,
        # should it be there
        delete $cfg->{$var};
    }
    else {
        $cfg->{$var} = $val;
    }
}


=head2 append

C<append> adds a new item to the hash or appends to an existing
item.

Here are the rules:

=over

=item I<Append New Item>

If there is yet no entry for the item you set, the item will be
created. In that sense, append works identically to L<"set">,
but you should still probably rather use set if you do not want
to append. Otherwise you would risk running into the situation
about which the author of L<Hash::MultiValue> says, that it
*sucks* having to, as a client, always work defensively like
shown in the

Example:

    $cfg->clear();

    # Set something by always using append...
    $cfg->append("a", "b");       # "a" is now a scalar "b"
    $cfg->append("a", "c");       # "a" is now an array ["b", "c"]

    # Later...

    my $content = $cfg->get("a"); # Is it now a scalar or an array?

    # Need to test defensively:
    my $must_scalar = ref $content eq 'ARRAY' ?   $content->[0] :  $content;
    my @maybe_multi = ref $content eq 'ARRAY' ? @{$content}     : ($content);

=begin testing AppendNewItem

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

=end testing

=item I<Append Non-Array to Non-Array>

Appending a non-array to a non-array (that is already there) will,
as shown in the previous example, create a new array and add both
the existing content as well as the new content, to that array.

As stated above, this could create some confusion if we would do it
on a simple set. That's why we do it only in append.

Example:

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", "c");
    my $res = $cfg->get("a");  # ["a", "b"]
    my @arr = @$res;           # or shorthand my @arr = @{ $cfg->get("a") }

=begin testing AppendNonArrayToNonArray

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

=end testing

=item I<Append Array to Non-Array>

Appending an array to a non array puts the existing, non-array,
content into the array that is put in.

You could argue that when appending an array to something that is
not an array, you might want to see an outer containing array that
has, as first entry, what was already there, and as second entry,
the new incoming array. While this would allow for having a nested
hierarchy of arrays, we know that we also want to be able to append
one array's content ot another's (see below). Therefore, if we want
to be able to do nested array, we can do this only on one level; at
the next level we'd already have an existing array, to which we are
then appending, hence we could nest only one level deep. Therefore,
if you want to have nested array, construct them outside, and then
just set them.

Example:

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", ["c", "d"]);
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d"]

=begin testing AppendArrayToNonArray

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", ["c", "d"]);
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d"]

    ok( @res == 3
     && ref \@res eq 'ARRAY',
       'Passed: append() - Append - ArrayToNonArray' );

=end testing

=item I<Append Non-Array to Array>

Appending a non-array to an array puts the new content into the
existing array.

Example:

    $cfg->clear();

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", "d");
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d"]

=begin testing AppendNonArrayToArray

    $cfg->clear();

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", "d");
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d"]

    ok( @res == 3
     && ref \@res eq 'ARRAY',
        'Passed: append() - Append - NonArrayToArray' );

=end testing

=item I<Append Array to Array>

Appending an array to another array that is already there will
append the items of the new array to those of the array that
was already there.

Example:

    $cfg->clear();

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", ["d", "e"]);
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d", "e"]

=begin testing AppendArrayToArray

    $cfg->clear();

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", ["d", "e"]);
    my @res = @{ $cfg->get("a") };  # ["b", "c", "d", "e"]

    ok( @res == 4
     && ref \@res eq 'ARRAY',
        'Passed: append() - Append - ArrayToArray' );

=end testing

=item I<Append Non-Hash to Hash>

Appending a non-hash to a hash will create a new entry in that
hash. For that to work, you have to pass in the optional parameter
that gives a name for that new entry (otherwise you'd be putting a
new element into something that is not yet an array, hence wrapping
the previously existing hash into an array, containg the hash as well
as the new item).

Example:

    $cfg->clear();

    # Set a hash:

    my %hash_in = ("b" => "c");

    $cfg->set("a", \%hash_in);

    # Later...

    $cfg->append("a", "d");                 # => Probably not what you want:

    my @array_out = @{ $cfg->get("a") };    # [ {'b' => 'c'}, 'd' ]

    # So let's do it right...

    $cfg->clear();
    $cfg->set("a", \%hash_in);
    $cfg->append("a", "d", "e");            # <= Give it a name - here: "e"

    my %hash_out = %{ $cfg->get("a") };     # {'b' => 'c', 'e' => 'd'}


=begin testing AppendNonHashToHash

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

=end testing

=item I<Append Hash to Hash>

Appending a hash to an existing hash merges both. Should the new hash
contain hash keys that already are present in the existing hash, the
values of the new hash will survive.

Example:

    $cfg->clear();

    # Set a hash:

    my %hash_ina = ("b" => "c", "d" => "e");
    my %hash_inb = ("d" => "f", "g" => "h");

    $cfg->set("a", \%hash_ina);
    $cfg->append("a", \%hash_inb);

    my %hash_out = %{ $cfg->get("a") };   # {'b' => 'c', 'd' => 'f', 'g' => 'h'}

=begin testing AppendHashToHash

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

=end testing

=item I<Advanced Example: Replace Array into Hash>

Of course, if you extend the previous example where we replaced
the existing value of the hash key 'd' by some other value, you
can also replace that value by something structurally different.
For example, you can replace an existing scalar for 'd' by some
array.

Example:

    $cfg->clear();

    # Set a hash:

    my %hash_ina = ("b" => "c", "d" => "e");
    my %hash_inb = ("d" => ["x", "y"], "g" => "h");

    $cfg->set("a", \%hash_ina);
    $cfg->append("a", \%hash_inb);

    my %hash_out = %{ $cfg->get("a") };   # {'b' => 'c', 'd' => ["x", "y"], 'g' => 'h'}


=begin testing AdvancedArrayIntoHash

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

=end testing


=item I<Advanced Example: Replacing undef into Hash (delete from)>

Likewise, we can delete from the hash that we already have, by passing
an undefined value into a known position. Passing undef again will be
a no-op, since the hash key inside the hash is not there.

Example:

    $cfg->clear();

    # Set a hash:

    my %hash_ina = ("b" => "c", "d" => "e");
    my %hash_inb = ("d" => ["x", "y"], "g" => "h");

    $cfg->set("a", \%hash_ina);
    $cfg->append("a", \%hash_inb);
    $cfg->append("a", undef, "d");

    my %hash_out = %{ $cfg->get("a") };   # {'b' => 'c', 'g' => 'h'}

=begin testing AdvancedRemoveInsideHash

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

=end testing

=item I<Advanced Example: Adding the same item under a different name>

If you add the same item under a different name, remember that it is
the same item still. So when you later modify that item, both copies
in the hash will be affected.

Example:

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

=begin testing AdvancedAddSameEntry

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

=end testing

=item I<Advanced Example: Get Hash as Array>

If you have a hash with an even number of elements, you can just get
it as an array with interleaved keys and values. Of course, you have
no control over the order of these pairs.

Example:

    $cfg->clear();

    # Set a hash:

    my %h = {"b" => "c", "d" => "e"};

    $cfg->set("a", \%h);

    my @a = %{ $cfg->get("a") };       # ["b", "c", "d", "e" ]

=begin testing GetHashAsArray

    $cfg->clear();

    # Set a hash:

    my %h = ("b" => "c", "d" => "e");

    $cfg->set("a", \%h);

    my @a = %{ $cfg->get("a") };       # [ "b", "c", "d", "e" ] or
                                       # [ "d", "e", "b", "c" ]

    ok( ( $a[0] eq "b" && $a[1] eq "c" && $a[2] eq "d" && $a[3] eq "e" )
     || ( $a[2] eq "b" && $a[3] eq "c" && $a[0] eq "d" && $a[1] eq "e" ),
        'Passed: append() - Advanced - GetHashAsArray');

=end testing

=back

=cut

#
# Append a value into the hash.
#
# Here we are more liberal as to what
# we want to do, depending on the data
# type and context.
#
# Appending to the holder should...
#
# 0 ... set the item if it is not there,
#   otherwise, ...
#
# 1 If there is something as $var that's
#   neither a hash nor an array (like, a
#   scalar or a ref), create a new array,
#   put the existing value into that new
#   array, and then if the new $val...
#
#    a is not an array, append $val to the
#      new array,
#    b is an array, put the elements of
#      $val into the new array
# 2 If there is an array named $var, then
#   if the new $val ...
#
#    a is not an array, append $val to
#      the existing array;
#    b is an array, append its elements
#      to the existing array
#
# 3 If there is something as $var that's
#   a hash, then if the new $val...
#
#    a is not a hash, then add it's $val
#      to the existing hash, using the
#      optional parameter $as as the
#      key for that $val. Note that in
#      the existing hash there already
#      was an entry with that key $as,
#      that entry will be replaced.
#      Adding explicitly undef will
#      remove the item from the hash.
#    b is a hash, merge it's content into
#      the existing hash;
#
sub append {
    my ( $self, $var, $val, $as, $arg_ref ) = @_;
    my $cfg = $self->{cfg_of};

    # 0 - there's nothing, so create an entry
    if ( !exists $cfg->{$var} ) {
        $self->set( $var, $val );
        return;
    }

    my $ex = $cfg->{$var};

    # 1 - there's not an array, so create one and append
    if ( ref $ex ne 'ARRAY' && ref $ex ne 'HASH' ) {
        if ( ref $val ne 'ARRAY' ) {
            # 1a - append
            $self->set( $var, [ $ex, $val ] );
        }
        else {
            # 1b - append elements
            my @newvar = ($ex);
            push @newvar, @{$val};
            $self->set( $var, \@newvar );
        }
        return;
    }

    # 2 - there's an array already
    if ( ref $ex eq 'ARRAY' ) {
        if ( ref $val ne 'ARRAY' ) {
            # 2a - append
            push @{$ex}, $val;
        }
        else {
            # 2b - append elements
            push @{$ex}, @{$val};
        }
        return;
    }

    # 3 - there's a hash
    if ( ref $ex eq 'HASH' ) {
        if ( ref $val ne 'HASH' ) {
            if ( defined $as ) {
                # If we have a name, ok
                # 3a - append
                if ( !defined $val ) {
                    delete $$ex{$as};
                }
                else {
                    $$ex{$as} = $val;
                }
            }
            else {
                # We don't have a name.
                # So essentially, this is 1a
                $self->set( $var, [ $ex, $val ] );
            }
        }
        else {
            # 3b - append elements
            @$ex{ keys %{$val} } = values %{$val};
        }
        return;
    }

    # 4 - else (should not happen)
    $self->set( $var, $val );
}


=head2 get

C<get> gets an item from the hash. Hopefully, it is a hashref.
You can also say, with the optional parameter, as what you want
to have it.

Example:

    $cfg->clear();

    $cfg->set("a", "b");

    my @aa = @{ $cfg->get("a", { 'as_array' => 1 }) }; # [ b ]
    my $sa =    $cfg->get("a");                        #  "b"

    $cfg->append("a", "c");

    my @ab = @{ $cfg->get("a") }; # <= [ "b", "c" ] (anyway array)
    my $sb =    $cfg->get("a");   # <= array ref

=begin testing GetAsArray

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

=end testing

=cut


sub get {
    my ( $self, $var, $arg_ref ) = @_;

    # Set defaults...
    my $as_array = $arg_ref->{'as_array'};

    my $cfg = $self->{cfg_of};

    my $res = $cfg->{$var};

    if(ref $res ne 'ARRAY' && $as_array) {
        return [$res];
    } else {
        return $res;
    }

}





sub clear {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->{cfg_of};

    foreach my $key ( keys %$cfg ) {
        delete $cfg->{$key};
    }

    return;
}

sub contains {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->{cfg_of};

    my $val    = $cfg->{$var};
    my $result = exists $cfg->{$var};
    return exists $cfg->{$var};
}





sub load {
    my ( $self, $ini ) = @_;

    if ( !defined $ini ) {
        return;
    }

    if ( !-f $ini ) {
        pod2usage(
            {   -message => "\nConfiguration file $ini not found\n",
                -exitval => 2,
            }
        );
    }

    #
    # Load the configuration File
    #
    my $config = new Config::Simple($ini);

    $self->{cfg_of}->{ini} = $config->{"_DATA"};

    #    try {
    #        cluck qq{This really did not work};
    #    }
    #    catch {
    #        say "Well, this didn't go a that well, did it:\n$_";
    #    }
}


sub describe {
    my ($self) = @_;

    return $self->{cfg_of};
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    print Dumper $self->describe();
}






no Moose;
__PACKAGE__->meta->make_immutable;

1;
