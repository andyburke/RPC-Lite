package RPC::Lite;

# documentation/placeholder package

our $VERSION = '0.0.5';

use RPC::Lite::Client;
use RPC::Lite::Server;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;
use RPC::Lite::Notification;

use RPC::Lite::Transport::TCP;

use RPC::Lite::Serializer::JSON;
use RPC::Lite::Serializer::Null;    

=pod

=head1 NAME

  RPC::Lite - A lightweight yet flexible framework for remote process
              communication.

=head1 DESCRIPTION

  Blah blah.

=head1 EXAMPLES

  ...

=cut

1;
