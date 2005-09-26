package RPC::Lite::Server;

use strict;

use threads;
use threads::shared;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Error;

my $DEBUG = $ENV{RPC_LITE_DEBUG};

my $systemPrefix         = 'system';
my $workerThreadsDefault = 10;

=pod

=head1 NAME

RPC::Lite::Server - Lightweight RPC server framework.

=head1 SYNOPSIS

  use RPC::Lite::Server;
  use RPC::Lite::Transport::TCP;
  use RPC::Lite::Serializer::JSON;

  my $server = RPC::Lite::Server->new(
    {
      Transport  => RPC::Lite::Transport::TCP->new(
        {
          ListenPort => 10000
        }
      ),
      Serializer => RPC::Lite::Serializer::JSON->new(),
    }
  );

  $server->Loop(); # never returns

=head1 DESCRIPTION

RPC::Lite::Server implements a very lightweight remote process
communications server framework.  It can use arbitrary Transport
(RPC::Lite::Transport) and Serialization (RPC::Lite::Serializer)
mechanisms.

The overriding goal of RPC::Lite is simplicity and elegant error
handling.

=cut

my %defaultMethods = (
                       "$systemPrefix.Uptime"             => \&RpcUptime,
                       "$systemPrefix.RequestCount"       => \&RpcRequestCount,
                       "$systemPrefix.SystemRequestCount" => \&RpcSystemRequestCount,
                     );

sub Serializer             { $_[0]->{serializer}             = $_[1] if @_ > 1; $_[0]->{serializer} }
sub Transport              { $_[0]->{transport}              = $_[1] if @_ > 1; $_[0]->{transport} }
sub StartTime              { $_[0]->{starttime}              = $_[1] if @_ > 1; $_[0]->{starttime} }
sub Threaded               { $_[0]->{threaded}               = $_[1] if @_ > 1; $_[0]->{threaded} }
sub ThreadPool             { $_[0]->{threadpool}             = $_[1] if @_ > 1; $_[0]->{threadpool} }
sub WorkerThreads          { $_[0]->{workerthreads}          = $_[1] if @_ > 1; $_[0]->{workerthreads} }
sub PoolJobs               { $_[0]->{pooljobs}          = $_[1] if @_ > 1; $_[0]->{pooljobs} }
sub RequestCount
{
  lock($_[0]->{requestcount});
  $_[0]->{requestcount} = $_[1] if @_ > 1;
  return $_[0]->{requestcount}
}
sub SystemRequestCount
{
  lock($_[0]->{systemrequestcount});
  $_[0]->{systemrequestcount} = $_[1] if @_ > 1;
  return $_[0]->{systemrequestcount}
}

sub IncRequestCount        { $_[0]->IncrementSharedField('requestcount') }
sub IncSystemRequestCount  { $_[0]->IncrementSharedField('systemrequestcount') }

# helper for atomic counters
sub IncrementSharedField
{
  my $self = shift;
  my $fieldName = shift;
  
  lock($self->{$fieldName});
  return ++$self->{$fieldName};
}


sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = { requestcount => undef, systemrequestcount => undef};
  bless $self, $class;
  share($self->{requestcount});
  share($self->{systemrequestcount});


  $self->StartTime( time() ); # no need to share; set once and copied to children
  $self->RequestCount(0);
  $self->SystemRequestCount(0);

  $self->Serializer( $args->{Serializer} ) or die('A serializer is required!');
  $self->Transport( $args->{Transport} )   or die('A transport is required!');

  $self->Threaded( $args->{Threaded} );
  $self->WorkerThreads( defined( $args->{WorkerThreads} ) ? $args->{WorkerThreads} : $workerThreadsDefault );

   $self->Initialize($args) if ( $self->can('Initialize') );

  return $self;
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

  $self->InitializeThreadPool();
  
  while (1)
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

  my $clientId = $self->Transport->GetNextRequestingClient;
  return if !defined($clientId);
  
  my $requestContent = $self->Transport->ReadRequestContent($clientId);
  return if !defined $requestContent;
  
  my $request  = $self->Serializer->Deserialize($requestContent);

  if($self->Threaded) # asynchronous operation
  {
    my $jobId = $self->ThreadPool->job($request);
    $self->PoolJobs->{$jobId} = $clientId; # store the client id for when job completes
    Debug("passing request to thread pool; jobid:$jobId");
  }
  else # synchronous
  {
    my $response = $self->DispatchRequest($request);
  
    # only send a response for requests, not for notifications
    if ( !$request->isa('RPC::Lite::Notification') )
    {
      $self->Transport->WriteResponseContent( $clientId, $self->Serializer->Serialize($response) );
    }
  }
}

# pump the thread pool and write out responses to clients
sub HandleResponses
{
  my $self = shift;

  return if !$self->Threaded;
  
  my @readyJobs = $self->ThreadPool->results();
  Debug("jobs finished: " . scalar(@readyJobs)) if @readyJobs;
  foreach my $jobId (@readyJobs)
  {
    my $response = $self->ThreadPool->result($jobId);
    my $clientId = $self->PoolJobs->{$jobId};
    $self->Transport->WriteResponseContent( $clientId, $self->Serializer->Serialize($response) );
    delete $self->PoolJobs->{$jobId};
    Debug("  id:$jobId");
  }
}

#
#############

##############
# The following are private methods.

sub InitializeThreadPool
{
  my $self = shift;
  
  return if !$self->Threaded or $self->ThreadPool;

  eval "use Thread::Pool";
  if ($@)
  {
    warn "Disabling threading for lack of Thread::Pool module.";
    $self->Threaded(0);
  }
  else
  {
    Debug('threading enabled');
    my $pool = Thread::Pool->new(
                                  {
                                    'workers' => $self->WorkerThreads,
                                    'do'      => sub { $self->DispatchRequest(@_) },
                                  }
                                );
    $self->ThreadPool($pool);    
    $self->PoolJobs({});
  }
}

=item FindMethod($method_name)

Returns a coderef to the method C<$method_name> in the server's implementation package,
or undef if it doesn't exist.

=cut

sub FindMethod
{
  my ( $self, $methodName ) = @_;

  Debug("looking for method in: " . ref($self));
  my $coderef = $self->can($methodName) || $defaultMethods{$methodName};

  return $coderef;
}

=item DispatchRequest($request)

Dispatches the RPC::Lite::Request C<$request> to the appropriate method in the
implementation package.  Returns an RPC::Lite::Response object containing the
return value from the method.

=cut

sub DispatchRequest
{
  my ( $self, $request ) = @_;

  ###########################################################
  ## keep track of how many method calls we've handled...
  if ( $request->Method !~ /^$systemPrefix\./ )
  {
    $self->RequestCount( $self->RequestCount + 1 );
  }
  else
  {
    $self->SystemRequestCount( $self->SystemRequestCount + 1 );
  }

  my $method = $self->FindMethod( $request->Method );
  my $response;

  if ($method)
  {

    # implementation package has the method, so we call it with the params
    Debug("dispatching to: " . $request->Method);
    eval { $response = $method->( $self, @{ $request->Params } ) };    # may return a pre-encoded Response, or just some data
    Debug("  returned");
    if ($@)
    {

      # method died

      # attempt to detect an Error.pm object
      my $error = $@;
      if ( UNIVERSAL::isa( $@, 'Error' ) )
      {
        $error = { %{$@} };                                            # copy the blessed hashref into a ref to a plain one
        $error->{jsonclass} = [ ref($@), [] ];                         # tell json this is an actual object of some class
      }

      $response = RPC::Lite::Error->new($error);                       # FIXME security issue - exposing implementation details to the client
    }
    elsif ( !UNIVERSAL::isa( $response, 'RPC::Lite::Response' ) )
    {

      # method just returned some plain data, so we construct a Response object with it
      $response = RPC::Lite::Response->new($response);
    }

    # else, the method returned a Response object already so we just let it be
  }
  else
  {

    # implementation package doesn't have the method
    $response = RPC::Lite::Error->new( "unknown method: " . $request->Method );
  }

  $response->Id( $request->Id );    # make sure the response's id matches the request's id

  return $response;
}


#=============

sub Debug
{
  return if !$DEBUG;

  my $message = shift;
  my ($package, $filename, $line, $subroutine) = caller(1);
  my $threadId = threads->tid;
  print STDERR "[$threadId] $subroutine: $message\n";
}

#=============

sub RpcUptime
{
  my $self = shift;

  return time() - $self->StartTime;
}

sub RpcRequestCount
{
  my $self = shift;

  return $self->RequestCount;
}

sub RpcSystemRequestCount
{
  my $self = shift;

  return $self->SystemRequestCount;
}

1;
