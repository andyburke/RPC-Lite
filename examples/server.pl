use strict;

use RPC::Lite::Server;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use Error;

my $server = TestServer->new(
  {
    Transport  => RPC::Lite::Transport::TCP->new( { ListenPort => 10000 } ),
    Serializer => RPC::Lite::Serializer::JSON->new(), 
  }
);

$server->Loop;

###########################

package TestServer;

use base qw(RPC::Lite::Server);
use Data::Dumper;

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

package BadPackage;

sub new
{
  my $class = shift;
  my $self = {};
  bless $self, $class;

  $self->{scalar} = 'scalar text';
  $self->{hashref} = { a => 1, b => 2 };
  $self->{arrayref} = [1, 2, 3];
  return $self;
}
