package RPC::Lite::Server;

use strict;

use threads;
use threads::shared;

use RPC::Lite::Session;
use RPC::Lite::SessionManager;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;
use RPC::Lite::Signature;

use Data::Dumper;

my $DEBUG = $ENV{RPC_LITE_DEBUG};

my $systemPrefix         = 'system';
my $workerThreadsDefault = 10;

=pod

=head1 NAME

RPC::Lite::Server - Lightweight RPC server framework.

=head1 SYNOPSIS

  use strict;

  use RPC::Lite::Server;

  my $server = ExampleServer->new(
    {
      Transports  => [ 'TCP:ListenPort=10000,LocalAddr=localhost' ],
      Serializers => [ 'JSON', 'XML' ],
      Threaded    => 1,
    }
  );

  $server->Loop;

  ###########################

  package ExampleServer;

  use base qw(RPC::Lite::Server);

  sub Initialize
  {
    my $self = shift;

    $self->AddSignature('GetTime=int:'); # optional signatures
  }

  sub GetTime
  {
    return time();
  }

  ...
 
=head1 DESCRIPTION

RPC::Lite::Server implements a very lightweight remote process
communications server framework.  It can use arbitrary Transport
(RPC::Lite::Transport) and Serialization (RPC::Lite::Serializer)
mechanisms.

The overriding goal of RPC::Lite is simplicity and elegant error
handling.

=cut

my %defaultMethods = (
                       "$systemPrefix.Uptime"             => \&_Uptime,
                       "$systemPrefix.RequestCount"       => \&_RequestCount,
                       "$systemPrefix.SystemRequestCount" => \&_SystemRequestCount,
                       "$systemPrefix.GetSignatures"      => \&_GetSignatures,
                       "$systemPrefix.GetSignature"       => \&_GetSignature,
                     );

sub SessionManager { $_[0]->{sessionmanager} = $_[1] if @_ > 1; $_[0]->{sessionmanager} }
sub StartTime      { $_[0]->{starttime}      = $_[1] if @_ > 1; $_[0]->{starttime} }
sub Threaded       { $_[0]->{threaded}       = $_[1] if @_ > 1; $_[0]->{threaded} }
sub ThreadPool     { $_[0]->{threadpool}     = $_[1] if @_ > 1; $_[0]->{threadpool} }
sub PoolJobs     { $_[0]->{pooljobs}     = $_[1] if @_ > 1; $_[0]->{pooljobs} }
sub WorkerThreads  { $_[0]->{workerthreads}  = $_[1] if @_ > 1; $_[0]->{workerthreads} }
sub Signatures     { $_[0]->{signatures}     = $_[1] if @_ > 1; $_[0]->{signatures} }

sub RequestCount
{
  lock( $_[0]->{requestcount} );
  $_[0]->{requestcount} = $_[1] if @_ > 1;
  return $_[0]->{requestcount};
}

sub SystemRequestCount
{
  lock( $_[0]->{systemrequestcount} );
  $_[0]->{systemrequestcount} = $_[1] if @_ > 1;
  return $_[0]->{systemrequestcount};
}

sub __IncRequestCount       { $_[0]->__IncrementSharedField( 'requestcount' ) }
sub __IncSystemRequestCount { $_[0]->__IncrementSharedField( 'systemrequestcount' ) }

# helper for atomic counters
sub __IncrementSharedField
{
  my $self      = shift;
  my $fieldName = shift;

  lock( $self->{$fieldName} );
  return ++$self->{$fieldName};
}

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = { requestcount => undef, systemrequestcount => undef };
  bless $self, $class;
  share( $self->{requestcount} );
  share( $self->{systemrequestcount} );

  $self->StartTime( time() );    # no need to share; set once and copied to children
  $self->RequestCount( 0 );
  $self->SystemRequestCount( 0 );

  $self->__InitializeSessionManager( $args->{Transports}, $args->{Serializers} );

  $self->Threaded( $args->{Threaded} );
  $self->WorkerThreads( defined( $args->{WorkerThreads} ) ? $args->{WorkerThreads} : $workerThreadsDefault );

  $self->Signatures( {} );

  $self->Initialize( $args ) if ( $self->can( 'Initialize' ) );

  return $self;
}

sub __InitializeSessionManager
{
  my $self           = shift;
  my $transportSpecs = shift;
  my $serializers    = shift;

  my $sessionManager = RPC::Lite::SessionManager->new(
                                                       {
                                                         TransportSpecs => $transportSpecs,
                                                         Serializers    => $serializers,
                                                       }
                                                     );

  die( "Could not create SessionManager!" ) if !$sessionManager;

  $self->SessionManager( $sessionManager );
}

############
# These are public methods that server authors may call.

=item Loop

Loops, calling HandleRequest, and does not return.  Useful for a trivial server that doesn't need
to do anything else in its event loop.  Transport subclasses should not override this as a server
process may skip Loop, calling HandleRequest directly.

=cut

sub Loop
{
  my $self = shift;

  $self->__InitializeThreadPool();

  while ( 1 )
  {
    $self->HandleRequest;
    $self->HandleResponses;
  }
}

=item HandleRequest

Handles a single request, dispatching it to the underlying RPC implementation class, and returns.

=cut

sub HandleRequest
{
  my $self = shift;

  my $sessionId = $self->SessionManager->GetNextReadySessionId();
  return if !defined( $sessionId );

  my $session = $self->SessionManager->GetSession( $sessionId );
  return if !defined( $session );

  my $request = $session->GetRequest();
  return if !defined $request;

  if ( $self->Threaded )    # asynchronous operation
  {
    __Debug( "passing request to thread pool" );
    # god, dirty, we need to save this return value or the
    # results will be discarded...
    my $jobId = $self->ThreadPool->job( $sessionId, $request );
    $self->PoolJobs->{$jobId} = $sessionId;
  }
  else                      # synchronous
  {
    my $result = $self->__DispatchRequest( $sessionId, $request );
    $session->Write( $result ) if defined( $result );
  }
}

# pump the thread pool and write out responses to clients
sub HandleResponses
{
  my $self = shift;

  return if !$self->Threaded;

  my @readyJobs = $self->ThreadPool->results();
  __Debug( "jobs finished: " . scalar( @readyJobs ) ) if @readyJobs;
  foreach my $jobId ( @readyJobs )
  {
    my $response = $self->ThreadPool->result( $jobId );
    my $sessionId = $self->PoolJobs->{$jobId};
    my $session = $self->SessionManager->GetSession( $sessionId );
    if ( defined( $session ) )
    {
      $session->Write( $response );
      __Debug( "  id:$jobId" );
    }
    delete $self->PoolJobs->{$jobId};
  }
}

#
#############

##############
# The following are private methods.

sub __InitializeThreadPool
{
  my $self = shift;

  return if !$self->Threaded or $self->ThreadPool;

  eval "use Thread::Pool";
  if ( $@ )
  {
    warn "Disabling threading for lack of Thread::Pool module.";
    $self->Threaded( 0 );
  }
  else
  {
    __Debug( 'threading enabled' );
    my $pool = Thread::Pool->new(
                                  {
                                    'workers' => $self->WorkerThreads,
                                    'do'      => sub { my $result = $self->__DispatchRequest( @_ ); return $result; },
                                  }
                                );
    $self->ThreadPool( $pool );
    $self->PoolJobs( {} );
  }
}

=item FindMethod($method_name)

Returns a coderef to the method C<$method_name> in the server's implementation package,
or undef if it doesn't exist.

=cut

sub __FindMethod
{
  my ( $self, $methodName ) = @_;

  __Debug( "looking for method in: " . ref( $self ) );
  my $coderef = $self->can( $methodName ) || $defaultMethods{$methodName};

  return $coderef;
}

=item DispatchRequest($request)

Dispatches the RPC::Lite::Request C<$request> to the appropriate method in the
implementation package.  Returns an RPC::Lite::Response object containing the
return value from the method.

=cut

sub __DispatchRequest
{
  my ( $self, $sessionId, $request ) = @_;

  ###########################################################
  ## keep track of how many method calls we've handled...
  if ( $request->Method !~ /^$systemPrefix\./ )
  {
    $self->__IncRequestCount();
  }
  else
  {
    $self->__IncSystemRequestCount();
  }

  my $method = $self->__FindMethod( $request->Method );
  my $response = undef;

  if ( $method )
  {

    # implementation package has the method, so we call it with the params
    __Debug( "dispatching to: " . $request->Method );
    eval { $response = $method->( $self, @{ $request->Params } ) };    # may return a pre-encoded Response, or just some data
    __Debug( "  returned:\n\n" );
    __Debug( Dumper $response );
    if ( $@ )
    {
      __Debug( "method died" );

      # attempt to detect an Error.pm object
      my $error = $@;
      if ( UNIVERSAL::isa( $@, 'Error' ) )
      {
        $error = { %{$@} };                                            # copy the blessed hashref into a ref to a plain one
      }

      $response = RPC::Lite::Error->new( $error );                     # FIXME security issue - exposing implementation details to the client
    }
    elsif ( !UNIVERSAL::isa( $response, 'RPC::Lite::Response' ) )
    {

      # method just returned some plain data, so we construct a Response object with it
      
      $response = RPC::Lite::Response->new( $response );
    }

    # else, the method returned a Response object already so we just let it be
  }
  else
  {

    # implementation package doesn't have the method
    $response = RPC::Lite::Error->new( "unknown method: " . $request->Method );
  }

  $response->Id( $request->Id );    # make sure the response's id matches the request's id

  use Data::Dumper;
  __Debug( "returning:\n\n" );
  __Debug(  Dumper $response ); 
  return $response;
}

#=============

sub AddSignature
{
  my $self            = shift;
  my $signatureString = shift;

  my $signature = RPC::Lite::Signature->new( $signatureString );

  if ( !$self->can( $signature->MethodName() ) )
  {
    warn( "Attempted to add a signature for a method [" . $signature->MethodName . "] we are not capable of!" );
    return;
  }

  $self->Signatures->{ $signature->MethodName } = $signature;
}

#=============

sub __Debug
{
  return if !$DEBUG;

  my $message = shift;
  my ( $package, $filename, $line, $subroutine ) = caller( 1 );
  my $threadId = threads->tid;
  print STDERR "[$threadId] $subroutine: $message\n";
}

#=============

sub _Uptime
{
  my $self = shift;

  return time() - $self->StartTime;
}

sub _RequestCount
{
  my $self = shift;

  return $self->RequestCount;
}

sub _SystemRequestCount
{
  my $self = shift;

  return $self->SystemRequestCount;
}

sub _GetSignatures
{
  my $self = shift;

  my @signatures;

  foreach my $methodName ( keys( %{ $self->Signatures } ) )
  {
    my $signature = $self->Signatures->{$methodName};

    push( @signatures, $signature->AsString() );
  }

  return \@signatures;
}

sub _GetSignature
{
  my $self       = shift;
  my $methodName = shift;

  return $self->Signatures->{$methodName}->AsString();
}

1;
