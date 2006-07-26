package RPC::Lite;

use strict;

# documentation/placeholder package

our $VERSION = '0.10';
our $HANDSHAKEFORMATSTRING = 'RPC-Lite %s / %s %s';

use RPC::Lite::Client;
use RPC::Lite::Server;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;
use RPC::Lite::Notification;

use RPC::Lite::Transport::TCP;

sub VersionSupported
{
  my $version = shift;
  
  # FIXME check if we support the protocol version
  return 1;
}

=pod

=head1 NAME

RPC::Lite - A lightweight yet flexible framework for remote process communication.

=head1 DESCRIPTION

RPC::Lite is intended to be a lightweight, easy-to-use yet flexible
and powerful RPC implementation.  It was inspired by the headaches of
working with other, heavier RPC APIs.

=head1 EXAMPLES

  use strict;

  use RPC::Lite::Client;

  # this will create a client object that will try to connect to
  # 192.168.0.3:10000 and use the JSON serializer.
  my $client = RPC::Lite::Client->new(
                                       {
                                         Transport  => 'TCP:Host=192.168.0.3,Port=10000',
                                         Serializer => 'JSON',
                                       }
                                     );    

  # print out the results of a call to the system.GetSignatures method
  print "GetSingatures: \n  " . Dumper($client->Request('system.GetSignatures')) . "\n\n";

  # print out the results of calling system.GetSignature( 'add' )
  print "GetSignature(add):\n  " . Dumper($client->Request('system.GetSignature', 'add')) . "\n\n";

  # ask the server to add two values together and return the result, $result = 3
  my $val1   = 1;
  my $val2   = 2;
  my $result = $client->Request( 'add', $val1, $val2 );
  # $result == 3
  
=cut

1;
