use strict;
use warnings;
package IO::Socket::Telnet::HalfDuplex;
use base 'IO::Socket::Telnet';

=head1 NAME

IO::Socket::Telnet::HalfDuplex - more reliable telnet communication

=head1 SYNOPSIS

  use IO::Socket::Telnet::HalfDuplex;
  my $socket = IO::Socket::Telnet::HalfDuplex->new(PeerAddr => 'localhost');
  while (1) {
      $socket->send(scalar <>);
      print $socket->read;
  }

=head1 DESCRIPTION


=cut

=head1 CONSTRUCTOR

=head2 new(PARAMHASH)

The constructor takes mostly the same arguments as L<IO::Socket::INET>, but
also accepts the key C<PingOption>, which takes an integer from 0-255 to use
for the ping/pong mechanism. This defaults to 99 if not specified.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $ping = delete $args{PingOption} || 99;
    my $self = $class->SUPER::new(@_);
    ${*{$self}}{ping_option} = $ping;
    $self->IO::Socket::Telnet::telnet_simple_callback(\&_telnet_negotiation);
    return $self;
}

sub telnet_simple_callback {
    my $self = shift;
    ${*$self}{halfduplex_simple_cb} = $_[0] if @_;
    ${*$self}{halfduplex_simple_cb};
}

=head1 METHODS

=cut

=head2 read()

Performs a (hopefully) full read on the socket. Returns the data read. Throws an exception if the connection ends before all data is read.

=cut

sub read {
    my $self = shift;
    my $buffer;

    $self->do(chr(${*{$self}}{ping_option}));
    ${*{$self}}{got_pong} = 0;

    eval {
        local $SIG{__DIE__};

        while (1) {
            my $b;
            defined $self->recv($b, 4096, 0) and do {
                $buffer .= $b;
                die "got pong\n" if ${*{$self}}{got_pong};
                next;
            };
            die "Disconnected from server: $!" unless $!{EINTR};
        }
    };

    die $@ if $@ !~ /^got pong\n/;

    return $buffer;
}

sub _telnet_negotiation {
    my $self = shift;
    my $option = shift;

    my $external_callback = ${*{$self}}{halfduplex_simple_cb};
    my $ping = ${*{$self}}{ping_option};
    if ($option =~ / $ping$/) {
        ${*{$self}}{got_pong} = 1;
        return '' unless $external_callback;
        return $self->$external_callback($option);
    }

    return unless $external_callback;
    return $self->$external_callback($option);
}

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-io-socket-telnet-halfduplex at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=IO-Socket-Telnet-HalfDuplex>.

=head1 SEE ALSO

L<IO::Socket::Telnet>, L<IO::Socket::INET>, L<IO::Socket>, L<IO::Handle>

L<http://www.ietf.org/rfc/rfc854.txt>

=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc IO::Socket::Telnet::HalfDuplex

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/IO-Socket-Telnet-HalfDuplex>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/IO-Socket-Telnet-HalfDuplex>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=IO-Socket-Telnet-HalfDuplex>

=item * Search CPAN

L<http://search.cpan.org/dist/IO-Socket-Telnet-HalfDuplex>

=back

=head1 AUTHOR

  Jesse Luehrs <doy at tozt dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
