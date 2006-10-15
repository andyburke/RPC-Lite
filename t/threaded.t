use Test::More;
use IO::Pipe;
use IO::Select;

use RPC::Lite;

my @serializerTypes = qw( XML JSON );

my  $numTests = 11 * @serializerTypes;

plan tests => $numTests;

my $server_control_pipe = IO::Pipe->new();

if ( my $pid = fork() ) # parent - client
{

  $server_control_pipe->writer;

  foreach my $serializerType ( @serializerTypes )
  {
  
    $client = RPC::Lite::Client->new(
      {
        Transport  => 'TCP:Host=localhost,Port=10000,Timeout=0.1',
        Serializer => $serializerType,
      }
    );

    ok( defined( $client ), "$serializerType client construction" );

    # should really do async requests, and fail if no response after N seconds
    is( $client->Request('slow'), 2,    'method call 1');
    is( $client->Request('method2'), 'foo', 'method call 2');

  }

  sleep(1);
  $server_control_pipe->print("\n");

}
elsif ( defined( $pid ) ) # child - server
{

  $server_control_pipe->reader;
  my $select = IO::Select->new([$server_control_pipe]);

  my $server = TestServer->new(
    {
      Transports  => [ 'TCP:Port=10000,Timeout=0.1' ],
    }
  );
  
  $server->HandleRequests until $select->can_read(0);

}
else
{
  print "failed to spawn server process\n";
}

###########################


package TestServer;

use base qw(RPC::Lite::Server);

sub Initialize
{
  my $self = shift;

  $self->AddSignature('add=int:int,int');
}

sub slow
{
  sleep(10);
  return 'slow';
}

sub fast
{
  return 'fast';
}