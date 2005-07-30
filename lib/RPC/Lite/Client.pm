package RPC::Lite::Client;

use strict;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;
use RPC::Lite::Notification;

use Data::Dumper;

our $VERSION = "0.0.1";

sub Serializer { $_[0]->{serializer} = $_[1] if @_ > 1; $_[0]->{serializer} }
sub Transport  { $_[0]->{transport}  = $_[1] if @_ > 1; $_[0]->{transport} }
sub IdCounter  { $_[0]->{idcounter}  = $_[1] if @_ > 1; $_[0]->{idcounter} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Serializer( $args->{Serializer} ) or die('A serializer is required!');
  $self->Transport( $args->{Transport} )   or die('A transport is required!');

  $self->IdCounter(1);

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
    if(!$@)
    {
      if (ref($response->Error) eq 'HASH' and defined $response->Error->{jsonclass}[0])
      {
        my $objectInitializer = delete $response->Error->{jsonclass};
        my ($class, @params) = @$objectInitializer;
        my $errorObject = eval { $class->new(@params) }; # FIXME pass jsonclass constructor params instead?
        if ($@)
        {
          $errorObject = $@; # FIXME improve? this will set the local eval error as the error message so the local user can see what they need to install
        }
        else
        {
          # brutalize the errorobject by slamming the key/value pairs straight into it without asking the accessors nicely
          while (my ($key, $value) = each %{$response->Error})
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

=item RequestResponse($methodName[, param[, ...]])

Sends a request to the server.  Returns an RPC::Lite::Response object.

=cut

# FIXME better name?
sub RequestResponse
{
  my $self = shift;

  $self->SendRequest( RPC::Lite::Request->new( shift, \@_ ) );    # method and params arrayref
  my $responseContent = $self->Transport->ReadResponseContent;
  my $response        = $self->Serializer->Deserialize($responseContent);

  if ( !defined($response))
  {
    return RPC::Lite::Error->new("received no data from server!");
  }
  if ( $response->Id != $self->IdCounter )
  {
    return RPC::Lite::Error->new("response id mismatch");
  }

  return $response;
}

=item Notify($methodName[, param[, ...]])

Sends a notification to the server, expects no response.

=cut

sub Notify
{
  my $self = shift;
$DB::single=1;
  $self->SendRequest( RPC::Lite::Notification->new( shift, \@_ ) );    # method and params arrayref
}

# FIXME sub NotifyResponse, for trapping local transport errors cleanly?

##############
# The following are private methods.

sub SendRequest
{
  my ( $self, $request ) = @_;    # request could be a Notification

  my $id = $self->IdCounter( $self->IdCounter + 1 );
  $request->Id($id);
  $self->Transport->WriteRequestContent( $self->Serializer->Serialize( $request ) );    
}

1;
