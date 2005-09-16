package RPC::Lite::Transport::TCP;

use strict;
use IO::Socket;
use IO::Select;

our $VERSION = "0.0.1";

sub Personality { $_[0]->{personality} = $_[1] if @_ > 1; $_[0]->{personality} }

# Client variables
sub Host         { $_[0]->{host}         = $_[1] if @_ > 1; $_[0]->{host} }
sub Port         { $_[0]->{port}         = $_[1] if @_ > 1; $_[0]->{port} }
sub IsConnected  { $_[0]->{isconnected}  = $_[1] if @_ > 1; $_[0]->{isconnected} }
sub Timeout      { $_[0]->{timeout}      = $_[1] if @_ > 1; $_[0]->{timeout} }
sub ClientSelect { $_[0]->{clientselect} = $_[1] if @_ > 1; $_[0]->{clientselect} }

# Server variables
sub LocalAddr     { $_[0]->{localaddr}     = $_[1] if @_ > 1; $_[0]->{localaddr} }
sub ListenPort    { $_[0]->{listenport}    = $_[1] if @_ > 1; $_[0]->{listenport} }
sub ListenSocket  { $_[0]->{listensocket}  = $_[1] if @_ > 1; $_[0]->{listensocket} }
sub CurrentSocket { $_[0]->{currentsocket} = $_[1] if @_ > 1; $_[0]->{currentsocket} }
sub IsListening   { $_[0]->{islistening}   = $_[1] if @_ > 1; $_[0]->{islistening} }
sub ServerSelect  { $_[0]->{serverselect}  = $_[1] if @_ > 1; $_[0]->{serverselect} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Personality( $args->{Personality} );

  if ( $self->IsClient )
  {
    $self->Host( $args->{Host} );
    $self->Port( $args->{Port} );
    $self->Timeout( $args->{Timeout} ); # defaults to undef, ie. infinite blocking
    $self->ClientSelect( IO::Select->new );
  }

  if ( $self->IsServer )
  {
    $self->ListenPort( $args->{ListenPort} );
    $self->LocalAddr( $args->{LocalAddr} );
    $self->ServerSelect( IO::Select->new );
  }

  return $self;
}

###############################################################
## Client Personality

sub IsClient
{
  my $self = shift;
  return ( !defined( $self->Personality ) or $self->Personality eq 'Client' );
}

sub ReadResponseContent
{
  my $self    = shift;
  my $timeout = @_ ? shift : $self->Timeout; # defaults to undef if not set by user (see new())

  return undef if !$self->IsClient;
  return undef if !$self->IsConnected;

  my $content = '';
  my $count   = 0;

  # FIXME comment this
  
  my ($socket) = $self->ClientSelect->can_read($timeout);

  if($socket)
  {
    while ( substr( $content, $count - 1, 1 ) ne chr(0) )
    {
      $count += $socket->sysread( $content, 1024, $count );
      return undef if $!;
    }
  
    chop($content);    # remove termination character
    return $content;
  }
}

sub WriteRequestContent
{
  my $self    = shift;
  my $content = shift;

  return undef if !$self->IsClient;

  $self->Connect or return undef;
  $content .= chr(0);
  my ($socket) = $self->ClientSelect->handles;
  # FIXME need to check if $socket is kosher?
  $socket->syswrite($content) == length($content) or return undef;

  return 1;
}

sub Connect
{
  my $self = shift;

  return undef if !$self->IsClient;

  return 1 if $self->IsConnected;

  # FIXME make sure this times out reasonably on failure
  my $socket = IO::Socket::INET->new(
                                      Proto    => 'tcp',
                                      PeerAddr => $self->Host,
                                      PeerPort => $self->Port,
                                      Blocking => 1,
                                     );    
  if ($socket)
  {
    $self->ClientSelect->add($socket);
    $self->IsConnected(1);
  }
  else
  {
    die($!); # FIXME this solution is a little extreme
  }

  return $self->IsConnected;
}

sub Disconnect
{
  my $self = shift;

  return undef if !$self->IsClient;

  $self->IsConnected(0);
  $self->ClientSelect->($self->ClientSelect->handles);
}

## End Client Personality
########################################################################

########################################################################
## Server Personality

sub IsServer
{
  my $self = shift;
  return ( !defined( $self->Personality ) or $self->Personality eq 'Server' );
}

sub ReadRequestContent
{
  my $self = shift;

  return undef if !$self->IsServer;

  $self->Listen;
  my ($socket) = $self->ServerSelect->can_read(.1);
  return undef if !$socket;

  if ( $socket == $self->ListenSocket )
  {
    $socket = $socket->accept;
    $self->ServerSelect->add($socket);
    return undef;
  }

  my $content = '';
  my $count   = 0;

  # FIXME comment this
  # FIXME allow for a user-set timeout
  while ( substr( $content, $count - 1, 1 ) ne chr(0) )
  {
    my $readBytes = $socket->sysread( $content, 1024, $count );
    $count += $readBytes;
    if ( $! or !$readBytes )
    {
      $self->ServerSelect->remove($socket);
      return undef;
    }
  }
  $self->CurrentSocket($socket);

  chop($content);    # eat off termination character
  return $content;
}

sub WriteResponseContent
{
  my ( $self, $content ) = @_;

  return undef if !$self->IsServer;

  defined( $self->CurrentSocket ) or die("CurrentSocket not defined!");

  $content .= chr(0);
  my $success = ( $self->CurrentSocket->syswrite($content) == length($content) );

  # disconnect on failure
  $self->ServerSelect->remove( $self->CurrentSocket ) if !$success;
  $self->CurrentSocket(undef);

  return $success;
}

sub Listen
{
  my $self = shift;

  return undef if !$self->IsServer;

  return 1 if $self->IsListening;

  $self->ListenSocket(
                       IO::Socket::INET->new(
                                              Listen    => 5,
                                              LocalPort => $self->ListenPort,
                                              LocalAddr => $self->LocalAddr,
                                              Proto     => 'tcp',
                                              Reuse     => 1,
                                            )
                     );
  if ( $self->ListenSocket )
  {
    $self->ServerSelect->add( $self->ListenSocket );
    $self->IsListening(1);
  }
  else
  {
    die($!);
  }

  return $self->IsListening;
}

## End Server Personality
################################################################################

1;
