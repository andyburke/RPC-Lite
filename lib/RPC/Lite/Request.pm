package RPC::Lite::Request;

use strict;
use RPC::Lite::Notification;
use Carp;

sub new
{
  my ( $class, $method, $params ) = @_;

  my $self = bless {}, $class;

  $self->Method($method);
  $self->Params($params);

  return $self;
}

sub Method     { $_[0]->{method}     = $_[1] if @_ > 1; $_[0]->{method} }
sub Params     { $_[0]->{params}     = $_[1] if @_ > 1; $_[0]->{params} }
sub Id         { $_[0]->{id}         = $_[1] if @_ > 1; $_[0]->{id} }

1;
