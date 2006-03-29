package RPC::Lite::SessionManager;

use strict;

my @defaultSerializers = qw( JSON XML Null );

sub Transports            { $_[0]->{transports}            = $_[1] if @_ > 1; $_[0]->{transports} }
sub Sessions              { $_[0]->{sessions}              = $_[1] if @_ > 1; $_[0]->{sessions} }
sub CurrentTransportIndex { $_[0]->{currentTransportIndex} = $_[1] if @_ > 1; $_[0]->{currentTransportIndex} }
sub Serializers           { $_[0]->{serializers} = $_[1] if @_ > 1; $_[0]->{serializers} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Sessions( {} );
  $self->Transports( [] );
  $self->Serializers( [] );
  $self->CurrentTransportIndex( 0 );

  die( "Must specify at least one transport type!" ) if !exists( $args->{TransportSpecs} );

  $self->__InitializeTransports( $args->{TransportSpecs} );
  $self->__InitializeSerializers( $args->{Serializers} );

  return $self;
}

sub __InitializeTransports
{
  my $self = shift;
  my $transportSpecs = shift;
  
  foreach my $transportSpec ( @{ $transportSpecs } )
  {
    my ( $transportClassName, $transportArgString ) = split( ':', $transportSpec, 2 );

    my $transportClass = 'RPC::Lite::Transport::' . $transportClassName;

    eval "use $transportClass";
    if ( $@ )
    {
      die( "Could not load transport of type [$transportClass]" );
    }

    my $transport = $transportClass->new( $transportArgString );
    if ( !defined( $transport ) )
    {
      die( "Could not construct transport: $transportClass" );
    }

    push( @{ $self->Transports }, $transport );
  }
}

sub __InitializeSerializers
{
  my $self = shift;
  my $serializers = shift;
  
  # default
  if ( ref( $serializers ) ne 'ARRAY' )
  {
    $serializers = \@defaultSerializers;
  }

  foreach my $serializerType ( @{$serializers} )
  {
    my $serializerClass = "RPC::Lite::Serializer::$serializerType";

    eval "use $serializerClass";
    if ( $@ )
    {
      warn( "Could not load serializer of type [$serializerClass]" );
      next;
    }

    push( @{ $self->Serializers }, $serializerClass->new() );
  }
}

sub GetNextReadySessionId
{
  my $self = shift;

  foreach my $sessionId ( keys %{ $self->Sessions } )
  {
    delete $self->Sessions->{$sessionId} if $self->Sessions->{$sessionId}->Disconnected();
  }

  my $numTransports     = scalar( @{ $self->Transports } );
  my $transportsChecked = 0;
  for ( my $transportIndex = $self->CurrentTransportIndex; $transportsChecked < $numTransports; ++$transportsChecked )
  {
    my $transport = $self->Transports->[$transportIndex];
    my $clientId  = $transport->GetNextRequestingClient;

    if ( defined( $clientId ) )
    {

      if ( !exists( $self->Sessions->{$clientId} ) )
      {

        # FIXME how to determine serializer type?
        $self->Sessions->{$clientId} = RPC::Lite::Session->new( $clientId, $transport, $self->Serializers, undef );
      }
      
      $self->CurrentTransportIndex( ( $transportIndex + 1 ) % $numTransports );
      return $clientId;
    }
    
    $transportIndex = ( $transportIndex + 1 ) % $numTransports;
  }

  return undef;
}

sub GetSession
{
  my $self = shift;
  my $sessionId = shift;
  
  return $self->Sessions->{$sessionId};
}

1;
