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
    my @array = @ { $cfg->get("something") };

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

    ok( defined($cfg) && ref $cfg eq $MODULE, 'Passed: new()' );

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

    # Initialize...
    my $cfg = TeXDown::TConfig->new();

    # Set something
    $cfg->set("a", "b");       # "a" is now a scalar "b"

=begin testing SetNew

    $cfg->set("a", "b");
    my $res = $cfg->get("a");
    ok( $res eq "b", 'Passed: set() - new' );

=end testing


=item I<Replace>

    # Later...
    $cfg->set("a", "c");       # "a" is now a scalar "c"

=begin testing SetReplace

    $cfg->set("a", "b");
    $cfg->set("a", "c");
    my $res = $cfg->get("a");
    ok( $res eq "c", 'Passed: set() - replace' );

=end testing


=item I<Remove>

    # Later...
    $cfg->set("a", undef);     # "a" is removed

=begin testing SetRemove

    $cfg->set("a", "b");
    $cfg->set("a", undef);
    my $res = $cfg->get("a");
    ok( !defined $res, 'Passed: set() - remove' );

=end testing

=back

When setting a non scalar, just remember to pass it as
a reference, otherwise you would be passing only the
first element. You'll get back a reference:

    # Set and get an array:

    my @array_in = ("b", "c");

    $cfg->set("a", \@array_in);

    # Later...

    my @array_out = @{ $cfg->get("a") };

Notice that the above construction of C<@array_in> created
an array. So let's recap three ways of doing the same thing:


    my @aa; do {@aa = (1, 2 ,3); \aa};  # <= @ax is array
    my @ab = (1, 2, 3);                 # <= @ax is an array - same thing
    my @ac = [1, 2, 3];                 # <= Not clean, rather do:
    my $ad = [1, 2, 3];                 # <= @az is a scalar that
                                                 is an array reference

In the C<@ac> case, we created a reference to an array, which
is what the use of square brackets does, but then stored it in
a variable C<@ac> rather than holding it as a scalar, as we do
it in C<$ad>. This confuses crap out of me, so I'm just saying...
Now, if we have a scalar, that's a reference to an array, we can
of course just set it:

    $cfg->set("ad", $ad);

And, because we did C<@ac> as we did, we could equally put that one
as

    $cfg->set("ac", @ac);  # <= Don't! You confuse even yourself!

But be aware that at some point in the future, this module may have
a way to detect that (it won't), and will really annoy you if you do.
For the actual arrays, rather do:

    $cfg->set("ab", \@ab); # <= Ahhh! This is nice.
    $cfg->set("aa", \@aa);


=begin testing SetArray

    my @array_in = ("b", "c");
    $cfg->set("a", \@array_in);
    my @array_out = @{ $cfg->get("a") };
    ok( @array_out == 2 && ref \@array_out eq 'ARRAY', 'Passed: set() - array' );

=end testing

    # Set and get a hash:

    my %hash_in = ("b" => "c");

    $cfg->set("a", \%hash_in);

    # Later...

    my %hash_out = %{ $cfg->get("a") };

In the following discussion, whenever I say C<scalar>, you
can also use the same for any reference. Depending on your
preference, you can of course also derefence later:

    $cfg->set("a", ["b", "c"]);
    my $arr_ref = $cfg->get("a");   # reference to ["a", "b"]

    # Later...

    my @arr = @$arr_ref;

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
*sucks* having to, as a client, always work defensively like so:


    # Initialize...
    my $cfg = TeXDown::TConfig->new();

    # Set something by always using append...
    $cfg->append("a", "b");       # "a" is now a scalar "b"
    $cfg->append("a", "c");       # "a" is now an array ["b", "c"]

    # Later...

    my $content = $cfg->get("a")  # Is it now a scalar or an array?

    # Need to test defensively:
    my @maybe_multi = ref $content eq 'ARRAY' ? @{$content} : ($content);
    my $must_scalar = ref $content eq 'ARRAY' ? $content->[0] : $content;


=item I<Append Non-Array to Non-Array>

Appending a non-array to a non-array (that is already there) will,
as shown in the previous example, create a new array and add both
the existing content as well as the new content, to that array.

Example:

    # Assume we have $cfg = TeXDown::TConfig->new();

    $cfg->set("a", "b");
    $cfg->append("a", "c");         # ["a", "b"]
    my @arr = @{ $cfg->get("a") };

=item I<Append Array to Non-Array>

Appending an array to a non array puts the existing, non-array,
content into the array that is put in.

Example:

    $cfg->set("a", "b");
    $cfg->append("a", ["c", "d"]);  # ["b", "c", "d"]

=item I<Append Non-Array to Array>

Appending a non-array to an array puts the new content into the
existing array.

Example:

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", "d");         # ["b", "c", "d"]

=item I<Append Array to Array>

Appending an array to another array that is already there will
append the items of the new array to those of the array that
was already there:

    $cfg->set("a", ["b", "c"]);
    $cfg->append("a", ["d", "e"])   # ["b", "c", "d", "e"]




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
        set( $var, $val );
        return;
    }

    my $ex = $cfg->{$var};

    # 1 - there's not an array, so create one and append
    if ( ref $ex ne 'ARRAY' && ref $ex ne 'HASH' ) {
        if ( ref $val ne 'ARRAY' ) {
            # 1a - append
            say "1a";
            set( $var, [ $ex, $val ] );
        }
        else {
            # 1b - append elements
            say "1b";
            my @newvar = ($ex);
            push @newvar, @{$val};
            set( $var, \@newvar );
        }
        return;
    }

    # 2 - there's an array already
    if ( ref $ex eq 'ARRAY' ) {
        if ( ref $val ne 'ARRAY' ) {
            # 2a - append
            say "2a";
            push @{$ex}, $val;
        }
        else {
            # 2b - append elements
            say "2b";
            push @{$ex}, @{$val};
        }
        return;
    }

    # 3 - there's a hash
    if ( ref $ex eq 'HASH' ) {
        if ( ref $val ne 'HASH' ) {
            # 3a - append
            say "3a";
            if ( !defined $val ) {
                delete $$ex{$as};
            }
            else {
                $$ex{$as} = $val;
            }
        }
        else {
            # 3b - append elements
            say "3b";
            @$ex{ keys %{$val} } = values %{$val};
        }
        return;
    }

    # 4 - else (should not happen)
    say "4";
    set( $var, $val );

}















sub get {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->{cfg_of};

    return $cfg->{$var};
}





sub clear {
    my ( $self, $var, $arg_ref ) = @_;
    my $cfg = $self->{cfg_of};

    my $content = $cfg->{$var};

    if ( ref $content eq 'ARRAY' && @$content ) {
        @$content = ();
    }

    delete $cfg->{$var};

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
