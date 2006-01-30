package RPC::Lite::SessionManager;

use strict;

sub Transport        { $_[0]->{transport}         = $_[1] if @_ > 1; $_[0]->{transport} }
sub Sessions         { $_[0]->{sessions}         = $_[1] if @_ > 1; $_[0]->{sessions} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Sessions({});

  my $transportClass = 'RPC::Lite::Transport::' . $args->{TransportType};

  eval "use $transportClass";
  if($@)
  {
    die("Could not load transport of type [$serializerClass]");
  }

  $self->Transport($transportClass->new());

  return $self;
}

sub GetNextReadySession
{
  my $self = shift;

  my $clientId = $self->Transport->GetNextRequestingClient;
  return undef if !defined($clientId);

  if(!exists($self->Sessions->{$clientId}))
  {
    # FIXME how to determine serializer type?
    $self->Sessions->{$clientId} = RPC::Lite::Session->new($clientId, $self->Transport, undef, undef); 
  }
}

1;
