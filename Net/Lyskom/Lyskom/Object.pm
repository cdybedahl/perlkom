package Net::Lyskom::Object;
use Data::Dumper;
use strict;
use warnings;

=head1 NAME

  Object - Net::Lyskom::Object

=head1 SYNOPSIS

use base qw{Net::Lyskom::Object};

=head1 DESCRIPTION

Ur-object from which all other Net::Lyskom object inherits. Is not
particularly useful on its own.

=head2 Methods

=over

=item ->as_string

Returns the current object as a string, serialized via Data::Dumper.
Mostly useful for debugging purposes.

=item ->gen_call_boolean($call,@args)

Sends call number $call with arguments @args to the server. Returns
undef if the server indicates a failure and the object itself if it
indicates success.

=item ->gen_call_scalar($call,@args)

As the previous, except that it returns a simple scalar from the
server call.

=back

=cut

sub as_string {
    my $s = shift;

    return Dumper $s;
}


# Generic server call with succeed/fail return semantics
sub gen_call_boolean {
    my $self = shift;
    my $call = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->send(
		join " ", $this,$call,@_,"\x0a"
	       );
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return $self;
    }
}

sub gen_call_scalar {
    my $self = shift;
    my $call = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->send(
		join " ", $this,$call,@_,"\x0a"
	       );
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return $res[1];
    }
}

sub server_call {
    my $self = shift;
    my $this = $self->{refno}++;

    $self->send(
		join " ", $this, @_, "\x0a"
	       );
    return $self->getres;
}

1;
