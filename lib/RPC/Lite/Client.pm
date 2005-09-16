package RPC::Lite::Client;

use strict;

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
  use RPC::Lite::Transport::TCP;
  use RPC::Lite::Serializer::JSON;

  my $client = RPC::Lite::Client->new(
    {
      Transport  => RPC::Lite::Transport::TCP->new(
        {
          Host => 'localhost',
          Port => 10000
        }
      ),
      Serializer => RPC::Lite::Serializer::JSON->new(),
    }
  );

  my $result = $client->Request('Hello World');

=head1 DESCRIPTION

RPC::Lite::Client implements a very lightweight remote process
communications client framework.  It can use arbitrary Transport
(RPC::Lite::Transport) and Serialization (RPC::Lite::Serializer)
mechanisms.

The overriding goal of RPC::Lite is simplicity and elegant error
handling.

=cut

sub Serializer    { $_[0]->{serializer}    = $_[1] if @_ > 1; $_[0]->{serializer} }
sub Transport     { $_[0]->{transport}     = $_[1] if @_ > 1; $_[0]->{transport} }
sub IdCounter     { $_[0]->{idcounter}     = $_[1] if @_ > 1; $_[0]->{idcounter} }
sub CallbackIdMap { $_[0]->{callbackidmap} = $_[1] if @_ > 1; $_[0]->{callbackidmap} }    

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Serializer( $args->{Serializer} ) or die('A serializer is required!');
  $self->Transport( $args->{Transport} )   or die('A transport is required!');

  $self->IdCounter(1);
  $self->CallbackIdMap({});

  $self->Initialize($args) if ( $self->can('Initialize') );

  return $self;
}

############
# These are public methods

# FIXME perldoc these

=item Request($methodName[, param[, ...]])

Sends a request to the server.  Returns a native object.

=cut

sub Request
{
  my $self = shift;

  my $response = $self->RequestResponse(@_);
  if ( $response->isa('RPC::Lite::Error') )
  {
    eval { require Error; };
    if ( !$@ )
    {
      if ( ref( $response->Error ) eq 'HASH' and defined $response->Error->{jsonclass}[0] )
      {
        my $objectInitializer = delete $response->Error->{jsonclass};
        my ( $class, @params ) = @$objectInitializer;
        my $errorObject = eval { $class->new(@params) };    # FIXME pass jsonclass constructor params instead?
        if ($@)
        {
          $errorObject = $@;                                # FIXME improve? this will set the local eval error as the error message so the local user can see what they need to install
        }
        else
        {

          # brutalize the errorobject by slamming the key/value pairs straight into it without asking the accessors nicely
          while ( my ( $key, $value ) = each %{ $response->Error } )
          {
            $errorObject->{$key} = $value;
          }
        }
        $response->Error($errorObject);
      }
    }

    # this is the "simple" interface to making a request, so we just die to keep it clean for the caller
    die( $response->Error );
  }

  return $response->Result;
}

=item AsyncRequest($callBack, $methodName[, param[, ...]])

Sends an asynchronous request to the server.  Takes a callback code reference.

=cut

sub AsyncRequest
{
  my $self       = shift;
  my $callBack   = shift;
  my $methodName = shift;

  # SendRequest returns the Id the given request was assigned
  my $requestId = $self->SendRequest($methodName, @_);
  $self->CallbackIdMap->{$requestId} = $callBack;
}

=item RequestResponse($methodName[, param[, ...]])

Sends a request to the server.  Returns an RPC::Lite::Response object.

=cut

# FIXME better name?
sub RequestResponse
{
  my $self = shift;

  $self->SendRequest( RPC::Lite::Request->new( shift, \@_ ) );    # method and params arrayref
  return $self->GetResponse();
}

=item Notify($methodName[, param[, ...]])

Sends a notification to the server, expects no response.

=cut

sub Notify
{
  my $self = shift;
  $self->SendRequest( RPC::Lite::Notification->new( shift, \@_ ) );    # method and params arrayref
}

sub Connect
{
  my $self = shift;
  $self->Transport->Connect();
}

# FIXME sub NotifyResponse, for trapping local transport errors cleanly?

##############
# The following are private methods.

sub SendRequest
{
  my ( $self, $request ) = @_;                                         # request could be a Notification

  my $id = $self->IdCounter( $self->IdCounter + 1 );
  $request->Id($id);
  $self->Transport->WriteRequestContent( $self->Serializer->Serialize($request) );
  return $id;
}

sub GetResponse
{
  my $self = shift;
  my $timeout = shift;

  my $responseContent = $self->Transport->ReadResponseContent($timeout);

  if (!length($responseContent))
  {
    if($timeout or $self->Transport->Timeout)
    {
      return; # no error, just no response yet
    }
    else
    {
      return RPC::Lite::Error->new("Error reading data from server!");
    }
  }
  
  my $response        = $self->Serializer->Deserialize($responseContent);

  if ( !defined($response) )
  {
    return RPC::Lite::Error->new("Could not deserialize response!");
  }

  if(exists($self->CallbackIdMap->{$response->Id}))
  {
    $self->CallbackIdMap->{$response->Id}->($response);
    delete $self->CallbackIdMap->{$response->Id};
  }
  else
  {
    return $response;
  }
}

1;
