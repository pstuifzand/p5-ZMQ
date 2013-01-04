use Test::More;
use Test::Fatal 'lives_ok';

use ZMQ;

my $ctx = ZMQ::Context->new(1);

# poller created with zero sockets
lives_ok {
    my $poller = ZMQ::Poller->new;
    my @r = $poller->poll(1000);
    is(@r, 0, 'not fired sockets');
} 'should return empty array for zero sockets';

done_testing();

