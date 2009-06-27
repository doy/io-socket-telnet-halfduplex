package IO::Socket::Telnet::HalfDuplex;
use base 'IO::Socket::Telnet';

sub new {
    my $class = shift;
    my %args = @_;
    my $code = delete $args{code} || 99;
    my $self = $class->SUPER::new(@_);
    ${*{$self}}{code} = $code;
    $self->telnet_simple_callback(\&telnet_negotiation);
    return $self;
}

sub read {
    my $self = shift;
    my $buffer;

    $self->do(chr(${*{$self}}{code}));
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

    my $code = ${*{$self}}{code};
    if ($option =~ / $code$/) {
        ${*{$self}}{got_pong} = 1;
        return '';
    }

    return;
}

1;
