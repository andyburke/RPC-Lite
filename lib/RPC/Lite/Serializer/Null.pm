package RPC::Lite::Serializer::JSON;

use strict;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Notification;
use RPC::Lite::Error;

our $DEBUG = $ENV{DEBUG_SERIALIZER};

sub new
{
  my $class = shift;
  my $self = {};
  bless $self, $class;
}

sub CannotDeserialize
{
  return 0;
}

sub Serialize
{
  return $_[1];
}

sub Deserialize
{
  return $_[1];
}

1;
