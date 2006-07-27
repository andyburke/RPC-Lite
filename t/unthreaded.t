use strict;

use Test::More tests => 1;

use RPC::Lite;


# FIXME should probe ports to find an open one. won't be totally race-proof but that shouldn't really be a problem. we could add a constructor param to allow passing in the listen socket... that's probably best.
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

my $done;
$client->AsyncRequest(sub { is($_[0]->Result, 5); $done = 1 }, 'add', 2, 3);

for (my $i = 0; $i < 10 and !$done; $i++)
{
  $server->HandleRequest;
  $client->HandleResponse;
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
