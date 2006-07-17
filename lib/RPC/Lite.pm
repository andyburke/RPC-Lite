package RPC::Lite;

use strict;

# documentation/placeholder package

our $VERSION = '0.1.0';
our $HANDSHAKEFORMATSTRING = 'RPC-Lite %s / %s %s';

use RPC::Lite::Client;
use RPC::Lite::Server;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;
use RPC::Lite::Notification;

use RPC::Lite::Transport::TCP;

=pod

=head1 NAME

  RPC::Lite - A lightweight yet flexible framework for remote process
              communication.

=head1 DESCRIPTION

  Blah blah.

=head1 EXAMPLES

  ...

=cut

sub VersionSupported
{
  my $version = shift;
  
  # FIXME check if we support the protocol version
  return 1;
}

1;
