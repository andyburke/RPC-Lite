package RPC::Lite::Session;

use strict;

sub StartTime       { $_[0]->{starttime}              = $_[1] if @_ > 1; $_[0]->{starttime} }
sub ClientId        { $_[0]->{clientid}               = $_[1] if @_ > 1; $_[0]->{clientid} }
sub Serializers     { $_[0]->{serializers}             = $_[1] if @_ > 1; $_[0]->{serializers} }
sub Serializer      { $_[0]->{serializer}             = $_[1] if @_ > 1; $_[0]->{serializer} }
sub Transport       { $_[0]->{transport}              = $_[1] if @_ > 1; $_[0]->{transport} }
sub Disconnected    { $_[0]->{disconnected}              = $_[1] if @_ > 1; $_[0]->{disconnected} }

sub new
{
  my $class          = shift;
  my $clientId       = shift;
  my $transport      = shift;
  my $serializers    = shift;
  my $extraInfo      = shift;

  my $self = {};
  bless $self, $class;

  $self->StartTime( $extraInfo->{StartTime} || time() );

  $self->ClientId( $clientId );
  $self->Transport( $transport );
  $self->Serializers( $serializers );
  $self->Serializer( undef );
  $self->Disconnected( 0 );

  return $self;
}

sub GetRequest
{
  my $self = shift;

  return undef if $self->Disconnected();

  my $requestContent = $self->Transport->ReadRequestContent($self->ClientId);

  if ( !defined($requestContent) )
  {
    $self->Disconnected( 1 );
    return;
  }
  
  return undef if !length($requestContent);

  if ( !defined( $self->Serializer ) )
  {
    if ( !$self->DetectSerializer( $requestContent ) )
    {
      $self->Disconnected( 1 );
      return undef;
    }
  }
  
  my $request = $self->Serializer->Deserialize($requestContent);

  return $request;
}

sub DetectSerializer
{
  my $self = shift;
  my $request = shift;
  
  foreach my $serializer ( @{ $self->Serializers } )
  {
    next if ( $serializer->CannotDeserialize( $request ) );
    
    $self->Serializer( $serializer );
    return 1;
  }
  
  return 0;
}

sub Write
{
  my $self = shift;
  my $data = shift;
  
  return $self->Transport->WriteResponseContent( $self->ClientId, $self->Serializer->Serialize( $data ) );
}

1;
