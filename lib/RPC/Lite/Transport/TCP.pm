package RPC::Lite::Transport::TCP;

use strict;

use threads;
use threads::shared;

use IO::Socket;
use IO::Select;

sub Personality { $_[0]->{personality} = $_[1] if @_ > 1; $_[0]->{personality} }

# Client variables
sub Host         { $_[0]->{host}         = $_[1] if @_ > 1; $_[0]->{host} }
sub Port         { $_[0]->{port}         = $_[1] if @_ > 1; $_[0]->{port} }
sub IsConnected  { $_[0]->{isconnected}  = $_[1] if @_ > 1; $_[0]->{isconnected} }
sub Timeout      { $_[0]->{timeout}      = $_[1] if @_ > 1; $_[0]->{timeout} }
sub ClientSelect { $_[0]->{clientselect} = $_[1] if @_ > 1; $_[0]->{clientselect} }

# Server variables
sub LocalAddr           { $_[0]->{localaddr}           = $_[1] if @_ > 1; $_[0]->{localaddr} }
sub ListenPort          { $_[0]->{listenport}          = $_[1] if @_ > 1; $_[0]->{listenport} }
sub ListenSocket        { $_[0]->{listensocket}        = $_[1] if @_ > 1; $_[0]->{listensocket} }
sub IsListening         { $_[0]->{islistening}         = $_[1] if @_ > 1; $_[0]->{islistening} }
sub ServerSelect        { $_[0]->{serverselect}        = $_[1] if @_ > 1; $_[0]->{serverselect} }
sub ClientIdMap         { $_[0]->{clientidmap}         = $_[1] if @_ > 1; $_[0]->{clientidmap} }
sub DisconnectedClients { $_[0]->{disconnectedclients} = $_[1] if @_ > 1; $_[0]->{disconnectedclients} }    

sub new
{
  my $class     = shift;
  my $argString = shift;

  my $self = {};
  bless $self, $class;

  my @args = split( ',', $argString );
  foreach my $arg ( @args )
  {
    my ($name, $value) = split( '=', $arg );
    
    if ( !$self->can( $name ) )
    {
      die( "Unknown argument: $name" );
    }
    
    $self->$name( $value );
  }
  
  if ( !$self->GuessPersonality() )
  {
    die( "Could not determine personality! (didn't set Host or ListenPort args?)" );
  }

  if ( $self->IsClient )
  {
    $self->Host or die( "Must specify a host to connect to!" );
    $self->Port or die( "Must specify port!" );
    $self->ClientSelect( IO::Select->new );
  }

  if ( $self->IsServer )
  {
    $self->ListenPort or die( "Must specify a port to listen on!" );
    $self->LocalAddr or $self->LocalAddr( 'localhost' );
    $self->ServerSelect( IO::Select->new );
    $self->ClientIdMap(         {} );
    $self->DisconnectedClients( {} );
    share( $self->{disconnectedclients} );
  }

  return $self;
}

sub GuessPersonality
{
  my $self = shift;
  
  if ( $self->ListenPort() )
  {
    $self->Personality( 'Server' );
    return 1;
  }
  
  if ( $self->Host() )
  {
    $self->Personality( 'Client' );
    return 1;
  }
  
  return 0;
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
  my $timeout = shift;

  # FIXME this logic still won't allow undef (infinite timeout) to be passed explicitly
  defined $timeout or $timeout = $self->Timeout;    # defaults to undef if not set by user (see new())

  return undef if !$self->IsClient;
  return undef if !$self->IsConnected;

  my $content = '';
  my $count   = 0;

  # FIXME comment this

  my ($socket) = $self->ClientSelect->can_read($timeout);

  if ($socket)
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
    die($!);    # FIXME this solution is a little extreme
  }

  return $self->IsConnected;
}

sub Disconnect
{
  my $self = shift;

  return undef if !$self->IsClient;

  $self->IsConnected(0);
  $self->ClientSelect->( $self->ClientSelect->handles );
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

# service the socket, returning next ready client or handle new incoming connection
sub GetNextRequestingClient
{
  my $self = shift;

  return undef if !$self->IsServer;

  $self->Listen;    # make sure our listen socket is established

  # reap disconnected clients
  {
    lock($self->{disconnectedclients});
    foreach my $clientId (keys %{$self->DisconnectedClients})
    {
      my $socket = IO::Socket::INET->new_from_fd( $self->ClientIdMap->{$clientId}, 'r+' );
      delete $self->DisconnectedClients->{$clientId};
      delete $self->ClientIdMap->{$clientId};
      $socket or next;
      $self->ServerSelect->remove($socket);
    }
  }

  my ($socket) = $self->ServerSelect->can_read(.01);    # try to find any ready clients
  return undef if !$socket;

  if ( $socket == $self->ListenSocket )                 # new connection
  {
    $socket = $socket->accept;
    $self->ServerSelect->add($socket);                  # add connection to our select list for service

    $self->ClientIdMap->{'TCP:' . fileno( $socket )} = fileno( $socket );          # keep a reference so that the socket is not GC'd

    return undef;                                  # don't really have a request from this client yet
  }

  return 'TCP:' . fileno( $socket );
}

sub ReadRequestContent
{
  my $self   = shift;
  my $clientId = shift;                                   # effective client id

  my $content = '';
  my $count   = 0;

  my $socket = IO::Socket::INET->new_from_fd( $self->ClientIdMap->{$clientId}, 'r+' );
  return undef if !$socket;

  # FIXME comment this
  # FIXME allow for a user-set timeout
  while ( substr( $content, $count - 1, 1 ) ne chr(0) )
  {
    my $readBytes = $socket->sysread( $content, 1024, $count );
    $count += $readBytes;
    if ( $! or !$readBytes )
    {
      lock($self->{disconnectedclients});
      $self->DisconnectedClients->{$clientId} = 1;
      return undef;
    }
  }

  chop($content);    # eat off termination character
  return $content;
}

sub WriteResponseContent
{
  my ( $self, $clientId, $content ) = @_;

  return undef if !$self->IsServer;

  my $success = 0;
  my $socket = IO::Socket::INET->new_from_fd( $self->ClientIdMap->{$clientId}, 'r+' );
  return $success if !$socket;

  $content .= chr(0);
  $success = ( $socket->syswrite($content) == length($content) );

  # disconnect on failure
  if ( !$success )
  {
    lock($self->{disconnectedclients});
    $self->DisconnectedClients->{$clientId} = 1;
    return $success;
  }

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
