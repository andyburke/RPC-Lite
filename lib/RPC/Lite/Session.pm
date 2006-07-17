package RPC::Lite::Session;

use strict;

use RPC::Lite;

sub StartTime      { $_[0]->{starttime}      = $_[1] if @_ > 1; $_[0]->{starttime} }
sub ClientId       { $_[0]->{clientid}       = $_[1] if @_ > 1; $_[0]->{clientid} }
sub SessionManager { $_[0]->{sessionmanager} = $_[1] if @_ > 1; $_[0]->{sessionmanager} }
sub SerializerType { $_[0]->{serializertype} = $_[1] if @_ > 1; $_[0]->{serializertype} }
sub Transport      { $_[0]->{transport}      = $_[1] if @_ > 1; $_[0]->{transport} }
sub Established    { $_[0]->{established}    = $_[1] if @_ > 1; $_[0]->{established} }
sub Disconnected   { $_[0]->{disconnected}   = $_[1] if @_ > 1; $_[0]->{disconnected} }

sub new
{
  my $class          = shift;
  my $clientId       = shift;
  my $transport      = shift;
  my $sessionManager = shift;
  my $extraInfo      = shift;

  my $self = {};
  bless $self, $class;

  $self->StartTime( $extraInfo->{StartTime} || time() );

  $self->ClientId( $clientId );
  $self->Transport( $transport );
  $self->SessionManager( $sessionManager );
  $self->SerializerType( undef );
  $self->Established( 0 );
  $self->Disconnected( 0 );

  return $self;
}

sub GetRequest
{
  my $self = shift;

  return undef if $self->Disconnected();

  my $requestContent = $self->Transport->ReadRequestContent( $self->ClientId );
  
  if ( !defined( $requestContent ) )
  {
    $self->Disconnected( 1 );
    return;
  }

  return undef if !length( $requestContent );

  # try to process the handshake
  if ( !$self->Established() )
  {
    chomp $requestContent;
    
    # handshake string examples:
    #
    #  RPC-Lite 1.0 / JSON 1.1
    #  RPC-Lite 2.2 / XML 3.2
    if ( $requestContent =~ /^RPC-Lite (.*?) \/ (.*?) (.*?)$/ )
    {
      my $rpcLiteVersion = $1;
      my $serializerType = $2;
      my $serializerVersion = $3;
      
      # FIXME return some kind of error to the client about why it's being dropped?
      
      if ( !RPC::Lite::VersionSupported( $rpcLiteVersion ) )
      {
        $self->Disconnected( 1 );
        return;
      }
      
      if ( !$self->SessionManager->__InitializeSerializer( $serializerType, $serializerVersion ) )
      {
        $self->Disconnected( 1 );
        return;
      }
      
      $self->SerializerType( $serializerType );
      $self->Established( 1 );
      return;
    }
    else
    {
      $self->Disconnected( 1 );
      return;
    }
  }
  
  my $request = $self->SessionManager->Serializers->{ $self->SerializerType() }->Deserialize( $requestContent );

  return $request;
}

sub Write
{
  my $self = shift;
  my $data = shift;

  my $serializedContent = $self->SessionManager->Serializers->{ $self->SerializerType() }->Serialize( $data );
  return $self->Transport->WriteResponseContent( $self->ClientId, $serializedContent );
}

1;
