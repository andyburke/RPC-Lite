use Test::More;
use IO::Pipe;
use IO::Select;

use RPC::Lite;

my @serializerTypes = qw( XML JSON );


my $threadTestServer = RPC::Lite::Server->new( { Threaded => 1 } );
if ( $threadTestServer->Threaded )
{
  my $numTests = 6 * @serializerTypes;
  plan tests => $numTests;
}
else
{
  plan skip_all => 'could not enable threading';
}
undef $threadTestServer;


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

    my ($gotSlow, $gotFast);
    $client->AsyncRequest(sub {
                            $gotSlow = 1;
                            is( $_[0], 'slow', 'slow call returned correct value' );
                            ok( $gotFast, 'slow returned after fast' );
                          },
                          'slow');
    $client->AsyncRequest(sub {
                            $gotFast = 1;
                            is( $_[0], 'fast', 'fast call returned correct value' );
                            ok( !$gotSlow, 'fast returned before slow' );
                          },
                          'fast');

    my $start = time;
    $client->HandleResponse until ($gotFast and $gotSlow) or (time > $start + 20);
    ok ( $gotFast && $gotSlow, 'got responses from both calls');

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
      Threaded    => 1,
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

sub slow
{
  sleep(10);
  return 'slow';
}

sub fast
{
  return 'fast';
}
