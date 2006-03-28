use strict;

use RPC::Lite::Server;
use RPC::Lite::Transport::TCP;

use Error;

use BadPackage;

my $threaded = $ARGV[0] eq '-t';

my $server = TestServer->new(
  {
    Transports  => [ 'TCP:ListenPort=10000,LocalAddr=localhost' ],
    Serializers => ['JSON', 'XML'],
    Threaded    => $threaded,
    Threaded    => 1,
  }
);

$server->Loop;

###########################

package TestServer;

use base qw(RPC::Lite::Server);
use Data::Dumper;

sub Initialize
{
  my $self = shift;

  $self->AddSignature('add=int:int,int');
  $self->AddSignature('MergeHashes = struct : array(struct)');
  $self->AddSignature('MergeArrays = array : array, array');

}

sub add
{
  my ( $server, $value1, $value2 ) = @_;

  return $value1 + $value2;
}

sub MergeHashes
{
  my ( $server, @hashes ) = @_;

  my $output = {};
  foreach my $hash (@hashes)
  {
    map { $output->{$_} = $hash->{$_} } keys %$hash;
  }

  return $output;
}

sub MergeArrays
{
  my ( $server, $array1, $array2 ) = @_;

  return [ @$array1, @$array2 ];
}

sub SortArray
{
  my ( $server, $array ) = @_;

  return [ sort @$array ];
}

sub Undef
{
  my ($server) = @_;

  return undef;
}

sub UndefArray
{
  return [undef, undef, undef, undef];
}

sub MixedUndefArray
{
  return [1, 2, undef, 3];
}

sub MixedArray
{
  return [1, 2, undef, { blah => 'yak', foo => undef }, [5, 6, undef, 7], 3];
}

sub Broken
{
  my ($server) = @_;

  throw Error::Simple("the server. it crush.");
}

sub BadType
{
  return BadPackage->new(); 
}

sub BadArray
{
  return [BadPackage->new(), BadPackage->new(), BadPackage->new()];
}

sub BadHash
{
  return { a => BadPackage->new(), b => BadPackage->new() };
}

sub BadNestedData
{
  my $bp = BadPackage->new();
  $bp->{bp} = BadPackage->new();
  return $bp;
}

sub GetUndef
{
  return undef;
}

sub SlowMethod
{
  sleep 10;
  return 'slow';
}

sub FastMethod
{
  sleep 1;
  return 'fast';
}
