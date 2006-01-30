package RPC::Lite::Session;

use strict;

sub StartTime       { $_[0]->{starttime}              = $_[1] if @_ > 1; $_[0]->{starttime} }
sub ClientId        { $_[0]->{clientid}               = $_[1] if @_ > 1; $_[0]->{clientid} }
sub Serializer      { $_[0]->{serializer}             = $_[1] if @_ > 1; $_[0]->{serializer} }
sub Transport       { $_[0]->{transport}              = $_[1] if @_ > 1; $_[0]->{transport} }

sub new
{
  my $class          = shift;
  my $clientId       = shift;
  my $transport      = shift;
  my $serializer     = shift;
  my $extraInfo      = shift;

  my $self = {};
  bless $self, $class;

  $self->StartTime($extraInfo->{StartTime} || time());

  $self->ClientId($clientId);
  $self->Transport($transport);
  $self->Serializer($serializer);

  return $self;
}

sub GetRequest
{
  my $self = shift;

  my $requestContent = $self->Transport->ReadRequestContent($self->ClientId);
  return undef if !defined($requestContent) or !length($requestContent);

  my $request = $self->Serializer->Deserialize($requestContent);

  return $request;
}

1;
