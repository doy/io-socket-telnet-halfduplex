use strict;
use warnings;
package IO::Socket::Telnet::HalfDuplex;
use base 'IO::Socket::Telnet';

sub new {
    my $class = shift;
    my %args = @_;
    my $ping = delete $args{ping_option} || 99;
    my $self = $class->SUPER::new(@_);
    ${*{$self}}{ping_option} = $ping;
    $self->IO::Socket::Telnet::telnet_simple_callback(\&telnet_negotiation);
    return $self;
}

sub telnet_simple_callback {
    my $self = shift;
    ${*$self}{halfduplex_simple_cb} = $_[0] if @_;
    ${*$self}{halfduplex_simple_cb};
}

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

sub telnet_negotiation {
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

1;
