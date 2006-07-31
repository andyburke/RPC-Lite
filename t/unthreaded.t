use strict;

use Test::More tests => 9;

use RPC::Lite;

my $gotResponse; 

# FIXME should probe ports to find an open one. will not be totally race-proof but that shouldn't really be a problem. we could add a constructor param to allow passing in the listen socket... that's probably best.
my $server = TestServer->new(
  {
    Transports  => [ 'TCP:ListenPort=10000,LocalAddr=localhost,Timeout=0.1' ],
  }
);

my $client = RPC::Lite::Client->new(
  {
    Transport  => 'TCP:Host=localhost,Port=10000,Timeout=0.1',
    Serializer => 'XML',
  }
);


# test calling add
$client->AsyncRequest(sub { is($_[0], 5, 'method call'); $gotResponse = 1 }, 'add', 2, 3);

Pump();

# test signature matching
my $signature1 = RPC::Lite::Signature->new( 'add=int:int,int' );
my $signature2 = RPC::Lite::Signature->new( 'add = int : int, int' );

ok( $signature1->Matches( $signature2 ), 'signature object matching' );
ok( $signature1->Matches( 'add=int:int,int' ), 'signature string matching' );

# test getting signatures
$client->AsyncRequest(sub { ok( $signature1->Matches( $_[0] ), 'Check system.GetSignature' ); $gotResponse = 1 }, 'system.GetSignature', 'add' );

Pump();

# guarantee an uptime of at least 1 second
sleep(1);

# test getting system.Uptime
$client->AsyncRequest( sub { ok( $_[0] > 0, 'Check system.Uptime' ); $gotResponse = 1 }, 'system.Uptime' );

Pump();

# test system.GetSignatures
$client->AsyncRequest( sub { ok( $_[0], 'Check system.GetSignatures' ); $gotResponse = 1; }, 'system.GetSignatures' );

Pump();

# test system.RequestCount
$client->AsyncRequest( sub { ok( $_[0] == 1, 'Check system.RequestCount' ); $gotResponse = 1; }, 'system.RequestCount' );

Pump();

# test system.SystemRequestCount
$client->AsyncRequest( sub { ok( $_[0] == 4, 'Check system.SystemRequestCount' ); $gotResponse = 1; }, 'system.SystemRequestCount' );

Pump();

# test getting back an RPC::Lite:Response object
$client->AsyncRequestResponseObject( sub { ok( $_[0]->isa( 'RPC::Lite::Response' ), 'AsyncRequestResponse test' ); $gotResponse = 1; }, 'system.Uptime' );

Pump();

sub Pump
{
  $gotResponse = 0;
  for (my $i = 0; $i < 10 and !$gotResponse; ++$i) 
  {        
    $server->HandleRequest; 
    $client->HandleResponse; 
  }
}

###########################


package TestServer;

use base qw(RPC::Lite::Server);

sub Initialize
{
  my $self = shift;

  $self->AddSignature('add=int:int,int');
}

sub add
{
  my ( $server, $value1, $value2 ) = @_;

  return $value1 + $value2;
}
