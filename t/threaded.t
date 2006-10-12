use Test::More;
use IO::Pipe;
use IO::Select;


plan tests => 3;

my $server_control_pipe = IO::Pipe->new();

if (my $pid = fork()) # parent - client
{

  $server_control_pipe->writer;

  ok(my $client = RPC::Lite::Client->new(...), 'client construction');
  # should really do async requests, and fail if no response after N seconds
  is($client->Request('method1'), 42,    'method call 1');
  is($client->Request('method2'), 'foo', 'method call 2');

  sleep(5);
  $server_control_pipe->print("\n");

}
elsif (defined $pid) # child - server
{

  $server_control_pipe->reader;
  my $select = IO::Select->new([$server_control_pipe]);

  my $server = TestServer->new(...);
  $server->HandleRequests until $select->can_read(0);

}
else
{
  print "failed to spawn server process\n";
}
