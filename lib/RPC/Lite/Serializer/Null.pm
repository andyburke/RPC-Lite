package RPC::Lite::Serializer::JSON;

use strict;
use base qw( RPC::Lite::Serializer );

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Notification;
use RPC::Lite::Error;

our $VERSION = '0.1';

our $DEBUG = $ENV{DEBUG_SERIALIZER};

sub VersionSupported
{
  return 1;
}

sub GetVersion
{
  return $VERSION;
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
