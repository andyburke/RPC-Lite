package RPC::Lite::SessionManager;

use strict;

sub Transports            { $_[0]->{transports}            = $_[1] if @_ > 1; $_[0]->{transports} }
sub Sessions              { $_[0]->{sessions}              = $_[1] if @_ > 1; $_[0]->{sessions} }
sub CurrentTransportIndex { $_[0]->{currentTransportIndex} = $_[1] if @_ > 1; $_[0]->{currentTransportIndex} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Sessions( {} );
  $self->Transports( [] );
  $self->CurrentTransportIndex( 0 );

  die( "Must specify at least one transport type!" ) if !exists( $args->{TransportSpecs} );

  foreach my $transportSpec ( @{ $args->{TransportSpecs} } )
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

  return $self;
}

sub GetNextReadySession
{
  my $self = shift;

  my $numTransports     = scalar( @$self->Transports );
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
        $self->Sessions->{$clientId} = RPC::Lite::Session->new( $clientId, $transport, undef, undef );
      }
      
      $self->CurrentTransportIndex( ( $transportIndex + 1 ) % $numTransports );
      return $self->Sessions->{$clientId};
    }
    
    $transportIndex = ( $transportIndex + 1 ) % $numTransports;
  }
}

1;
