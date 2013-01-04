package ZMQ::Poller;
use strict;

use ZMQ;

sub new {
    my ($class) = @_;
    my $self = bless {
        items => [],
        dirty => 0,
    }, $class;
    return $self;
}

sub register {
    my ($self, $socket, $events) = @_;
    push @{$self->{items}}, { socket => $socket, events => $events };
    $self->{dirty} = 1;
    return;
}

sub unregister {
    my ($self, $socket) = @_;
    @{$self->{items}} = grep { !($_->{socket} == $socket) } @{$self->{items}};
    $self->{dirty} = 1;
    return;
}

sub _create_poll_items {
    my $self = shift;

    if ($self->{dirty}) {
        $self->{pollitems} = [];

        my @fired      = ((0) x scalar @{$self->{items}});
        $self->{fired} = \@fired;

        my $i = 0;

        for (@{$self->{items}}) {

            my $callback = (sub { my ($fired, $n) = @_; return sub { $fired->[$n] = 1; }; })->($self->{fired}, $i);

            if (ref($_->{socket}) eq 'ZMQ::Socket') {
                push @{$self->{pollitems}}, { socket => $_->{socket}{_socket}, events => $_->{events}, callback => $callback };
            }
            elsif (ref($_->{socket}) eq 'ZMQ::LibZMQ2::Socket') {
                push @{$self->{pollitems}}, { socket => $_->{socket}, events => $_->{events}, callback => $callback };
            }
            elsif (ref($_->{socket}) eq 'ZMQ::LibZMQ3::Socket') {
                push @{$self->{pollitems}}, { socket => $_->{socket}, events => $_->{events}, callback => $callback };
            }
            elsif ($_->{socket} =~ m/^\d+$/) {
                push @{$self->{pollitems}}, { fd => int($_->{socket}), events => $_->{events}, callback => $callback };
            }
            else {
                die "Unknown type of socket";
            }
        }
        continue { $i++; };

        $self->{dirty} = 0;
    }
    for (@{$self->{fired}}) {
        $_ = 0;
    }
    return;
}

sub poll {
    my ($self, $timeout) = @_;

    $self->_create_poll_items();

    my @pollitems = @{$self->{pollitems}};

    my @rv = ZMQ::call('zmq_poll', \@pollitems, $timeout);

    my @res;

    my $c = 0;
    for (@{$self->{fired}}) {
        push @res, $self->{items}->[$c] if $self->{fired}[$c];
    }
    continue { $c++; }

    return @res;
}

1;

__END__


=head1 NAME

ZMQ::Poller - Stateful wrapper around zmq_poll

=head1 SYNOPSIS

    use ZMQ;
    use ZMQ::Constants qw/:all/;

    my $ctx = ZMQ::Context->new;

    my $push = $ctx->socket(ZMQ_PUSH);
    $push->bind('tcp://127.0.0.1:5908');

    my $pull = $ctx->socket(ZMQ_PULL);
    $pull->connect('tcp://127.0.0.1:5908');

    my $poller = ZMQ::Poller->new;
    $poller->register($push, ZMQ_POLLOUT);
    $poller->register($pull, ZMQ_POLLIN);

    my $cnt = 0;

    POLL: for (;;) {
        my @fired = $poller->poll(1000); # 1 second timeout

        for (@fired) {
            if ($_->{socket} == $push && $_->{events} == ZMQ_POLLOUT) {
                $push->sendmsg("Hello world");
            }
            elsif ($_->{socket} == $pull && $_->{events} == ZMQ_POLLIN) {
                my $msg = $pull->recvmsg;
                print $msg->data . "\n";
                last POLL if ++$cnt == 10;
            }
        }
    }

=head1 DESCRIPTION

ZMQ::Poller is a stateful wrapper around zmq_poll.

=head1 METHODS

=head2 ZMQ::Poller->new;

Creates a new poller object.

=head2 $poller->register($socket, ZMQ_POLLOUT|ZMQ_POLLIN)
=head2 $poller->register($fd, ZMQ_POLLOUT|ZMQ_POLLIN)

Register a socket or file descriptor for polling.

=head2 $poller->unregister($socket)
=head2 $poller->unregister($fd)

Remove the socket or file descriptor from the poller. If the same socket or
file descriptor is registered for different events then all these objects are
removed from the poller.

=head2 $poller->poll($timeout)

Poll the registered sockets. Returns an array of the sockets and file
descriptors that fired. If no sockets or file descriptors fire within the
timeout an empty array is returned.

Specify $timeout in milliseconds.

=head1 SEE ALSO

L<ZMQ>, L<ZMQ::Socket>

L<http://zeromq.org>

=head1 AUTHOR

Peter Stuifzand E<lt>peter@stuifzand.euE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Peter Stuifzand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

