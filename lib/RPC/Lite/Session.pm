package RPC::Lite::Session;

use strict;

sub StartTime       { $_[0]->{starttime}              = $_[1] if @_ > 1; $_[0]->{starttime} }
sub SerializerType  { $_[0]->{serializertype}         = $_[1] if @_ > 1; $_[0]->{serializertype} }

sub new
{
  my $class = shift;
  my $args  = shift;
  my $info = shift;

  my $self = {};
  bless $self, $class;

  $self->StartTime($info->{StartTime} || time());
  $self->SerializerType($info->{SerializerType});

  return $self;
}

1;
