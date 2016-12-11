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
use Try::Tiny;

use Exporter 'import';

our @EXPORT_OK = qw/ t_as_string /;

sub t_as_string {
    my $self = shift;
    my $res  = "";
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
