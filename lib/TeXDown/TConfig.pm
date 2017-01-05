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
use Data::Dump "pp";
use Pod::Usage;
use Config::Simple;

use Moose;
with 'MooseX::Log::Log4perl';

use namespace::autoclean -except => sub { $_ =~ m{^t_.*} };

use TeXDown::TFileResolver;
use TeXDown::TUtils qw/ t_as_string /;


=begin testing SETUP

###################################################
#
# Test Setup
#
###################################################

my $MODULE       = 'TeXDown::TConfig';

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

my $cfg = TeXDown::TConfig->new();

$cfg->load($INI);

=end testing

=cut


has cfg => (
    is      => 'rw',
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
    $self->cfg( $arg_ref->{cfg} ) if exists $arg_ref->{cfg};
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
    my $cfg = $self->cfg;

    $self->log->trace( "$var = " . $self->t_as_string($val) );

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
    my $cfg = $self->cfg;

    $self->log->trace(
        "$var = " . $self->t_as_string( $val, $as, $arg_ref ) );

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
        }    #  if ( ref $val ne 'HASH' )
        else {
            # 3b - append elements
            @$ex{ keys %{$val} } = values %{$val};
        }
        return;
    }    # if ( ref $ex eq 'HASH' )

    # 4 - else (should not happen)
    $self->set( $var, $val );
}


=head2 get

C<get> gets an item from the hash. Hopefully, it is a hashref.
You can also say, with the optional parameter, if you want to
have it wrapped in an array, should it not yet be an array.

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

Using the optional parameter C<condense>, you can specify, if you
did ask for C<as_array>, that you want to remove all empty strings
and undefined stuff from the array before returning.

Example:

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", "");
    $cfg->append("a", "d");

    # Gets ["b", "d"]:
    my @array = @{ $cfg->get("a", { 'as_array' => 1, 'condense' => 1}) };

=begin testing GetAsArrayCondensed

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->append("a", "");
    $cfg->append("a", "d");

    # Gets ["b", "d"]:
    my @array = @{ $cfg->get("a", { 'as_array' => 1, 'condense' => 1}) };

    ok( ref \@array eq 'ARRAY'
     && scalar @array == 2,
     'Passed: get() - GetAsArrayCondensed');

=end testing

=cut


sub get {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    my $log = "$var " . $self->t_as_string($arg_ref) . ": ";

    my $as_array = $arg_ref->{'as_array'};
    my $condense = $arg_ref->{'condense'};

    my $res = $cfg->{$var};

    if ($as_array) {
        if ( !defined $res ) {
            # Wants an array, but has no data: Return an
            # empty array.
            $self->log->trace( $log . $self->t_as_string( [] ) );
            return [];
        }
        elsif ( ref $res eq 'ARRAY' ) {
            if ( !$condense ) {
                $self->log->trace( $log . $self->t_as_string($res) );
                return $res;
            }

            my @arr_res = ();
            # Wants an array, has an array: Return the array,
            # but remove all empty bits from it.
            foreach my $arr_entry (@$res) {
                if ( defined $arr_entry && $arr_entry ne "" ) {
                    push @arr_res, $arr_entry;
                }
            }

            $self->log->trace( $log . $self->t_as_string(@arr_res) );
            return \@arr_res;
        }    # elsif ( ref $res eq 'ARRAY' )
        else {
            # Wants an array, has only one, non-array, value:
            # return wrapped as array
            if ( !$condense ) {
                $self->log->trace( $log . $self->t_as_string( [$res] ) );
                return [$res];
            }

            if ( defined $res && $res ne "" ) {
                $self->log->trace( $log . $self->t_as_string( [$res] ) );
                return [$res];
            }
            else {
                $self->log->trace( $log . $self->t_as_string( [] ) );
                return [];
            }
        }
    }    # if ($as_array)
    else {
        # Does not specify whether wants an array. So
        # if there is an array, we return it, but we
        # remove the empty parts from it.
        if ( ref $res eq 'ARRAY' ) {
            if ( !$condense ) {
                $self->log->trace( $log . $self->t_as_string($res) );
                return $res;
            }

            my @arr_res = ();
            foreach my $arr_entry (@$res) {
                if ( defined $arr_entry && $arr_entry ne "" ) {
                    push @arr_res, $arr_entry;
                }
            }

            $self->log->trace( $log . $self->t_as_string(@arr_res) );
            return \@arr_res;
        }    # if ( ref $res eq 'ARRAY' )
        else {
            # We don't have an array, so just return whatever is
            # there
            $self->log->trace( $log . $self->t_as_string($res) );
            return $res;
        }
    }    # else: ! $as_array

    # Original version - keeping for reference at
    # the moment, was too simple as it did not
    # support condensing.
    #
    #   if ( ref $res ne 'ARRAY' && $as_array ) {
    #       return [$res];
    #   }
    #   else {
    #       return $res;
    #   }

}


=head2 clear

C<clear> removes all items from the hash. With the optional
parameter C<keep>, you can pass in an array of hash keys which
you want to not remove. Using the optional parameter C<only>,
you can pass in an array of keys that you want to remove only,
rather than removing everything (C<keep> applies in both cases).
If you call clear just without any parameters, everything will
be cleared.

Example:

    $cfg->clear();

    $cfg->set("x", "a");
    $cfg->set("y", "b");
    $cfg->set("z", "c");

    $cfg->clear({'keep' => ["x", "z"], 'only' => ["x", "y"]});

    my $x = $cfg->get("x"); # defined  : asked to remove by only, but protected by keep
    my $y = $cfg->get("y"); # undefined: removed
    my $z = $cfg->get("z"); # defined  : not in list of keys to remove

=begin testing Clear

    $cfg->clear();

    $cfg->set("x", "a");
    $cfg->set("y", "b");
    $cfg->set("z", "c");

    $cfg->clear({'keep' => ["x", "z"], 'only' => ["x", "y"]});

    my $x = $cfg->get("x");
    my $y = $cfg->get("y");
    my $z = $cfg->get("z");

    ok(  defined $x
     && !defined $y
     &&  defined $z,
     'Passed: clear()');

=end testing

=cut


sub clear {
    my ( $self, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    $self->log->trace( "Clearing " . $self->t_as_string($arg_ref) );

    my $skeep = $arg_ref->{'keep'};
    my @akeep = ( defined $skeep ) ? @$skeep : ();
    my %hkeep = map { $_ => 1 } @akeep;

    my $sonly = $arg_ref->{'only'};

    if ( defined $sonly ) {
        my @only = @$sonly;
        foreach my $key (@only) {
            $self->remove($key) unless exists $hkeep{$key};
        }

    }
    else {
        foreach my $key ( keys %$cfg ) {
            $self->remove($key) unless exists $hkeep{$key};
        }
    }

    return;
}


=head2 key_set

C<key_set> gets all the keys that are currently defined.

Example:

    $cfg->clear();

    $cfg->set("scalar", "SCALAR");
    $cfg->set("array",  [ "a", "b" ]);
    $cfg->set("hash",   { "a" => "b" });

    my @keys = $cfg->key_set();

    foreach my $key (@keys) {
        my $value = $cfg->get($key);
        say "$key => ", (ref $value eq "") ? $value : (ref $value);
    }

=begin testing KeySet

    $cfg->clear();

    $cfg->set("scalar", "SCALAR");
    $cfg->set("array",  [ "a", "b" ]);
    $cfg->set("hash",   { "a" => "b" });

    my @keys = $cfg->key_set();

    foreach my $key (@keys) {
        my $value = $cfg->get($key);
        my $test  = (ref $value eq "") ? $value : (ref $value);
        ok ( uc $key eq $test,
             'Passed: key_set() - Iterating ' . $test);
    }

=end testing

=cut

sub key_set {
    my ( $self, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    $self->log->trace( $self->t_as_string( keys %$cfg, $arg_ref ) );

    return keys %$cfg;
}


=head2 contains_key

C<key_set> returns true if the key is already present.

Example:

    $cfg->clear();

    $cfg->set("a", "b");

    if ($cfg->contains_key("a")) {
        say "Found a";
    }

=begin testing ContainsKey

    $cfg->clear();

    $cfg->set("a", "b");

    ok ( $cfg->contains_key("a")
     && !$cfg->contains_key("b"),
         'Passed: contains_key()');

=end testing

=cut

sub contains_key {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    my $res = exists $cfg->{$var};

    $self->log->trace( "$var : "
            . ( $res ? "(yes) " : "(no) " )
            . $self->t_as_string($arg_ref) );

    return $res;
}


=head2 remove

C<key_set> removes a given key from the hash.

Example:

    $cfg->clear();

    $cfg->set("a", "b");

    say "Found a" if $cfg->contains_key("a");

    $cfg->remove("a");

    say "a was removed" if !$cfg->contains_key("a");

=begin testing Remove

    $cfg->clear();

    $cfg->set("a", "b");

    $cfg->remove("a");

    $cfg->remove("b"); # We don't want to fail this

    ok ( !$cfg->contains_key("a"),
         'Passed: remove()');

=end testing

=cut

sub remove {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    $self->log->trace( $self->t_as_string( $var, $arg_ref ) );

    delete $cfg->{$var};
}


=head2 size

C<key_set> returns the number of entries in the hash.

Example:

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->set("e", "f");
    $cfg->set("a", "g"); # <= overwrite

    say "A has ", $cfg->size(), " entries.";

=begin testing Size

    $cfg->clear();

    $cfg->set("a", "b");
    $cfg->set("e", "f");
    $cfg->set("a", "g"); # <= overwrite

    ok ( $cfg->size() == 2,
         'Passed: size()');

=end testing

=cut

sub size {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    my $size = keys %$cfg;

    $self->log->trace( $self->t_as_string( $size, $arg_ref ) );

    return $size;
}


=head2 is_empty

C<key_set> checks whether the hash is empty.

Example:

    $cfg->clear();

    say "Hash is empty" if !$cfg->is_empty();

=begin testing IsEmpty

    $cfg->clear();

    say "Hash is empty" if !$cfg->is_empty();

    ok ( $cfg->is_empty()
      && $cfg->size() == 0,
         'Passed: is_empty()');

=end testing

=cut

sub is_empty {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    $self->log->trace( "+ " . ( 0 == keys %$cfg ) );

    return 0 == keys %$cfg;
}


=head2 add_all

C<key_set> adds a complete hash to the hash, potentially
overwriting what is already there for any key given.

Example:

    $cfg->clear();

    $cfg->set("a", "b");

    $cfg->add_all( { "e" => "f", "g" => "h", "a" => "c" } );

=begin testing AddAll

    $cfg->clear();

    $cfg->set("a", "b");

    $cfg->add_all( { "e" => "f", "g" => "h", "a" => "c" } );

    ok ( $cfg->get("a") eq "c"
      && $cfg->size() == 3,
         'Passed: add_all()');

=end testing

=cut

sub add_all {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    $self->log->trace( $self->t_as_string( $var, $arg_ref ) );

    if ( ref $var ne 'HASH' ) {
        confess "Can only add_all a hash";
    }

    #
    # @merge are keys that, if we find them in any
    # of the keys in %cfg, we don't want to replace
    # the key in %cfg, but replace it's value by the
    # values of the same key we find in the new
    # hash to add.
    #
    #
    # Example: we have p=("a", "b", "c") and we merge
    # p=("d", "e"). Normally, we would now have
    # p=("d", "e"), but if we say to merge on ("b"),
    # we would now have p=("a", "d", "e", "c").
    #


    my $smerge = $arg_ref->{'merge'};
    my @merge  = ( defined $smerge ) ? @$smerge : ();
    my %hmerge = map { $_ => 1 } @merge;

    # Simple variant: Overwrite
    if ( @merge == 0 ) {
        @$cfg{ keys %$var } = values %$var;
        return;
    }

    # Complex variant: Merge
MERGE:
    foreach my $key ( keys %$var ) {
        my $curvals = $cfg->{$key};

        if ( 'ARRAY' ne ref $curvals ) {
            # Only one value so far => simple overwrite
            $self->set( $key, $var->{$key} );
            next MERGE;
        }
        else {
            # We have an array, so look for whether to
            # overwrite any of its values. If no such
            # value, we append the new values.

            my @newvals = ();
            my $merged  = 0;

            foreach my $curval (@$curvals) {
                if ( exists $hmerge{$curvals} ) {
                    push( @newvals, $var->{$key} );
                    $merged = 1;
                }
                else {
                    push( @newvals, $curval );
                }
            }

            # If we did not merge them in, they are new,
            # so let's append them
            #
            if ( !$merged ) {
                push( @newvals, $var->{$key} );
            }

            # Set the @newvals, replacing what was there
            $self->set( $key, \@newvals );
        }
    }    # MERGE: foreach my $key ( keys %$var )
}



=head2 load

C<load> loads the content of a file into the hash.
The hash is not automatically cleared first, which
means, you can merge files.

Example:

    $cfg->clear();

    $cfg->load("t/texdown-test.ini", {'protect_global' => 0});

=begin testing Load

    $cfg->clear();

    $cfg->load("t/texdown-test.ini", {'protect_global' => 0});

    ok ( $cfg->get("test-key") eq "global",
         'Passed: load()');

=end testing

So here's how the function works: Since you typically will have
loaded some variables through the command line, like so:

    my $cfg = TeXDown::TConfig->new();

    GetOptions(
        'c|cfg:s'           => sub { $cfg->append(@_); },
        # ...
        'p|project:s{,}'    => sub { $cfg->append(@_); },
    ) or pod2usage(2);

    $cfg->load($cfg->get("c"), { protect_global => 0 });

The last line in the above example then instructs to load the
configuration file, which may typically have been passed in
as the configuration variable C<-c>, e.g., like

    -c t/textdown-test.ini

In addition, the parameter C<-p> is used to specify the
projects that are to be loaded. For example, you can have
multiple projects on the command line, like so:

    -p abc -p roilr -p xyz

After loading the file that's specified through C<-c>, the
C<load> function walks through all projects that were given,
on the command line, through C<-p>. For each of those projects,
if it does not find an equivalent entry as a block in the
configuration file, it will leave the value untouched. For
others, it will replace that value by the values found in
the configuration file.

For example, assume that you have this content in the
configuration file:

    [roilr]
    p=123, 456

and you have given the above command line:

    -p abc -p roilr -p xyz

The net result will be as if you had specified, on the command
line:

    -p abc -p 123 -p 456 -p xyz

Since neither C<abc> nor C<xyz> were found in the configuration file,
they were left untouched; conversely, since C<roilr> was found in
the configuration file and had a line there starting with C<p=>, its
contents - C<123> and C<456> - have replaced the value C<roilr>
that was given on the command line.

What's more, there is the option of specifying any other variable in those
sections. If you have some other variable, e.g., C<klm=opq> in a section
of the configuration file that you had referred to using C<-p>, that
variable will then be loaded into the hash, so that you can get it
using the C<get> function.

Note that if you are using multiple references into the configuration
file, the variables of the last reference will survive. In other words,
if you do

    -p abc -p roilr -p rd -p xyz

and you have this configuration file:

    [roilr]
    p=123, 456
    klm=opq

    [rd]
    p=789
    klm=rst

You will find these values in the hash:

    p=abc, 123, 456, 789, xyz
    klm=rst

Finally, you can use the C<[GLOBAL]> section in the configuration
file. If you set the (optional) C<protect_global> variable to 1,
those values will not be overwritten by whatever is specified in
any given section. If you want the C<[GLOBAL]> settings to survive,
you need to pass in C<protect_global=>1>:

    # GLOBAL variables can be overwritten:

    $cfg->load($cfg->get("c"), { protect_global => 0 }); # Standard, , same as
    $cfg->load($cfg->get("c"));

    # GLOBAL survives:
    $cfg->load($cfg->get("c"), { protect_global => 1 });

In other words, if you have this command line:

    -p abc -p roilr -p rd -p xyz

and this configuration file:

    [GLOBAL]
    klm=uvw

    [roilr]
    p=123, 456
    klm=opq

    [rd]
    p=789
    klm=rst

You will find these values in the hash if you had C<protect_global=0>,
which is the default:

    p=abc, 123, 456, 789, xyz
    klm=rst

If you had, yet, C<protect_global=1>, then that value would survive,
and you'd have:

    p=abc, 123, 456, 789, xyz
    klm=uvw

=cut

sub load {
    my ( $self, $ini, $arg_ref ) = @_;
    my $cfg = $self->cfg;

    $self->log->trace( "> " . "-" x 40 );

    my $config_file;

    #
    # If we were not given an ini file to read from,
    # we attempt to load it by checking whether we
    # have a "c" attribute.
    if ( !defined $ini || $ini eq "" ) {
        if ( $self->contains_key("c") ) {
            $config_file = $self->get("c");
        }

    }
    else {
        $config_file = $ini;
    }

    if ( !-f $config_file ) {
        pod2usage(
            {   -message => "\nConfiguration file $config_file not found\n",
                -exitval => 2,
            }
        );
    }

    #
    # Load the configuration File
    #
    $self->log->info("Loading Config: $config_file");

    my $config = new Config::Simple($config_file);

    #
    # Load GLOBAL first unless specified not to do so,
    # allowing later variables to overwrite GLOBAL ones.
    #
    my $protect_global
        = ( defined $arg_ref->{'protect_global'} )
        ? $arg_ref->{'protect_global'}
        : 0;

    if ( !$protect_global && defined $config ) {
        $self->add_all( $config->param( -block => "GLOBAL" ) );
    }

    # for each p that we have, we are going to locate it
    # in our config file. If it exists, we are going to
    # load it's variables, eventually overwriting what was
    # already there. And for the p of that project itself,
    # we are going to replace the value in our ps by those
    # of that declared in the config file.

    # Get all p's specified on the command line
    my @cmd_ps = @{ $self->get( "p", { 'as_array' => 1 } ) };

    # Create a new holder where we'll collect them all
    my @all_ps = ();

    # Traverse all the projects we may have been given
    # on the command line; their names may be shortcuts
    # to blocks in the configuration file
    if ( defined $config ) {
        foreach my $cmd_p (@cmd_ps) {

            # Should we have none... (undefined - like, in testing)
            next if !defined $cmd_p;

            # Get the variables for the current cmd line project
            my %cmd_p_vars = %{ $config->param( -block => "$cmd_p" ) };

            if ( !keys %cmd_p_vars || !exists $cmd_p_vars{"p"} ) {
                # We have no specification on the project in ini,
                # so we maintain what's on the command line
                push @all_ps, $cmd_p;

                $self->log->trace(
                    "Project $cmd_p was not found in configuration file, leaving untouched"
                );
                next;
            }

            # Now we know that we have a block [rd] in the
            # configuratin file, and that this block contains
            # a p= specification of projects. Since we did not
            # append rd into the @all_ps array, we now append
            # all the values of rd.p into @all_ps.
            #
            # Or, of what we find is even not a project (p)
            # specification, we'll just read what's in that
            # configuration and put it into the hash itself.
            foreach my $cmd_p_var ( keys %cmd_p_vars ) {
                if ( $cmd_p_var ne "p" ) {
                    $self->set( $cmd_p_var, $cmd_p_vars{$cmd_p_var} );
                }
                else {
                    my $cmd_p_vals = $cmd_p_vars{$cmd_p_var};
                    $self->log->trace( "Project $cmd_p was specified as "
                            . $self->t_as_string($cmd_p_vals) );

                    if ( ref $cmd_p_vals eq 'ARRAY' ) {
                        push @all_ps, @{$cmd_p_vals};
                    }
                    else {
                        push @all_ps, $cmd_p_vals;
                    }
                }
            }    # foreach my $cmd_p_var ( keys %cmd_p_vars )
        }    # foreach my $cmd_p (@cmd_ps)
    }    # if ( defined $config )

    # Set the array of (re-) collected project definitions
    if ( scalar @all_ps ) {
        $self->set( "p", \@all_ps );
    }


    #
    # If told that global should prevail,
    # load it only now
    #
    if ( $protect_global && defined $config ) {
        $self->add_all( $config->param( -block => "GLOBAL" ) );
    }

    $self->log->trace( "< " . "-" x 40 );
}


sub describe {
    my ($self) = @_;

    return $self->cfg;
}

sub dump {
    my ($self) = @_;
    $Data::Dumper::Terse = 1;
    $self->log->trace( sub { Data::Dumper::Dumper( $self->describe ) } );
}





no Moose;
__PACKAGE__->meta->make_immutable;

1;
