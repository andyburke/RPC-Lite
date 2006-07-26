package RPC::Lite::Client;

use strict;

use RPC::Lite;
use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;
use RPC::Lite::Notification;

use Data::Dumper;

=pod

=head1 NAME

RPC::Lite::Client - Lightweight RPC client framework.

=head1 SYNOPSIS

  use RPC::Lite::Client;

  my $client = RPC::Lite::Client->new(
    {
      Transport  => 'TCP:Host=blah.foo.com,Port=10000',
      Serializer => 'JSON',
    }
  );

  my $result = $client->Request('Hello World');

=head1 DESCRIPTION

RPC::Lite::Client implements a very lightweight remote process
communications client framework.  It can use arbitrary Transport
(RPC::Lite::Transport) and Serialization (RPC::Lite::Serializer)
mechanisms.

=over 12

=cut

sub SerializerType { $_[0]->{serializertype} = $_[1] if @_ > 1; $_[0]->{serializertype} }
sub Serializer     { $_[0]->{serializer}     = $_[1] if @_ > 1; $_[0]->{serializer} }
sub Transport      { $_[0]->{transport}      = $_[1] if @_ > 1; $_[0]->{transport} }
sub IdCounter      { $_[0]->{idcounter}      = $_[1] if @_ > 1; $_[0]->{idcounter} }
sub CallbackIdMap  { $_[0]->{callbackidmap}  = $_[1] if @_ > 1; $_[0]->{callbackidmap} }
sub Connected      { $_[0]->{connected}  = $_[1] if @_ > 1; $_[0]->{connected} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Connected( 0 );
  
  $self->__InitializeSerializer( $args->{Serializer} );
  $self->__InitializeTransport( $args->{Transport} );

  $self->IdCounter( 1 );
  $self->CallbackIdMap( {} );

  $self->Initialize( $args ) if ( $self->can( 'Initialize' ) );

  return $self;
}

sub __InitializeSerializer
{
  my $self           = shift;
  my $serializerType = shift;

  my $serializerClass = 'RPC::Lite::Serializer::' . $serializerType;

  eval "use $serializerClass";
  if ( $@ )
  {
    die( "Could not load serializer of type [$serializerClass]" );
  }

  my $serializer = $serializerClass->new();
  if ( !defined( $serializer ) )
  {
    die( "Could not construct serializer: $serializerClass" );
  }

  $self->SerializerType( $serializerType );
  $self->Serializer( $serializer );
}

sub __InitializeTransport
{
  my $self = shift;

  my $transportSpec = shift;

  my ( $transportType, $transportArgString ) = split( ':', $transportSpec, 2 );

  my $transportClass = 'RPC::Lite::Transport::' . $transportType;

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

  $self->Transport( $transport );
}

############
# These are public methods

=pod

=item Connect()

Explicitly connects to the server.  If this method is not called, the client will
attempt to automatically connect when the first request is sent.

=cut

sub Connect
{
  my $self = shift;
  
  return 1 if ( $self->Connected() );

  $self->Transport->Connect();

  my $handshakeContent = sprintf( $RPC::Lite::HANDSHAKEFORMATSTRING, $RPC::Lite::VERSION, $self->SerializerType(), $self->Serializer->GetVersion() );
  $self->Transport->WriteRequestContent( $handshakeContent );
  
  $self->Connected( 1 );
  return 1;
}

=pod

=item Request($methodName[, param[, ...]])

Sends a request to the server.  Returns a native object that is the result of the request.

=cut

sub Request
{
  my $self = shift;

  my $response = $self->RequestResponse( @_ );
  if ( $response->isa( 'RPC::Lite::Error' ) )
  {
    eval { require Error; };
    if ( !$@ )
    {
      if ( ref( $response->Error ) eq 'HASH' and defined $response->Error->{jsonclass}[0] )
      {
        my $objectInitializer = delete $response->Error->{jsonclass};
        my ( $class, @params ) = @$objectInitializer;
        my $errorObject = eval { $class->new( @params ) };    # FIXME pass jsonclass constructor params instead?
        if ( $@ )
        {
          $errorObject = $@;                                  # FIXME improve? this will set the local eval error as the error message so the local user can see what they need to install
        }
        else
        {

          # brutalize the errorobject by slamming the key/value pairs straight into it without asking the accessors nicely
          while ( my ( $key, $value ) = each %{ $response->Error } )
          {
            $errorObject->{$key} = $value;
          }
        }
        $response->Error( $errorObject );
      }
    }

    # this is the "simple" interface to making a request, so we just die to keep it clean for the caller
    die( $response->Error );
  }

  return $response->Result;
}

=pod

=item AsyncRequest($callBack, $methodName[, param[, ...]])

Sends an asynchronous request to the server.  Takes a callback code
reference.  After calling this, you'll probably want to call
HandleResponse in a loop to check for a response from the server, at
which point your callback will be executed and passed the result
value.

=cut

sub AsyncRequest
{
  my $self       = shift;
  my $callBack   = shift;
  my $methodName = shift;

  # __SendRequest returns the Id the given request was assigned
  my $requestId = $self->__SendRequest( RPC::Lite::Request->new( $methodName, \@_ ) );
  $self->CallbackIdMap->{$requestId} = $callBack;
}

=pod

=item RequestResponse($methodName[, param[, ...]])

Sends a request to the server.  Returns an RPC::Lite::Response object.

=cut

# FIXME better name?
sub RequestResponse
{
  my $self = shift;

  $self->__SendRequest( RPC::Lite::Request->new( shift, \@_ ) );    # method and params arrayref
  return $self->__GetResponse();
}

=pod

=item Notify($methodName[, param[, ...]])

Sends a notification to the server, expects no response.

=cut

sub Notify
{
  my $self = shift;
  $self->__SendRequest( RPC::Lite::Notification->new( shift, \@_ ) );    # method and params arrayref
}

# FIXME sub NotifyResponse, for trapping local transport errors cleanly?


=pod

=item HandleResponse([$timeout])

Checks for a response from the server.  Useful mostly in conjunction
with AsyncRequest.  You can pass a timeout, or the Transport's default
timeout will be used.  Returns an Error object if there was an error,
otherwise returns undef.

=cut

sub HandleResponse
{
  my $self       = shift;
  my $timeout    = shift;

  return $self->__GetResponse($timeout);
}




##############
# The following are private methods.

sub __SendRequest
{
  my ( $self, $request ) = @_;    # request could be a Notification

  return -1 if ( !$self->Connect() );

  my $id = $self->IdCounter( $self->IdCounter + 1 );
  $request->Id( $id );
  $self->Transport->WriteRequestContent( $self->Serializer->Serialize( $request ) );
  return $id;
}

sub __GetResponse
{
  my $self    = shift;
  my $timeout = shift;

  my $responseContent = $self->Transport->ReadResponseContent( $timeout );

  if ( !defined $responseContent or !length $responseContent )
  {
    if ( $timeout or $self->Transport->Timeout )
    {
      return;    # no error, just no response yet
    }
    else
    {
      return RPC::Lite::Error->new( " Error reading data from server !" );
    }
  }

  my $response = $self->Serializer->Deserialize( $responseContent );

  if ( !defined( $response ) )
  {
    return RPC::Lite::Error->new( " Could not deserialize response !" );
  }

  if ( exists( $self->CallbackIdMap->{ $response->Id } ) )
  {
    $self->CallbackIdMap->{ $response->Id }->( $response );
    delete $self->CallbackIdMap->{ $response->Id };
  }
  else
  {
    return $response;
  }
}

1;
