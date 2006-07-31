package RPC::Lite::Transport;

=pod

=head1 NAME

RPC::Lite::Transport -- Transport base class.

=head1 DESCRIPTION

RPC::Lite::Transport is the base for implementing transport layers
for RPC::Lite.  Transports have two 'personalities': client and server.
All transports must implement the following methods:

=cut

sub new
{
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

=pod

=over 4

=item Client Personality

=over 4

=cut

=pod

=item IsClient()

Returns a boolean value indicating whether the transport is in the
'Client' personality.

=cut

sub IsClient() { die( "Unimplemented virtual function!" ) }

=pod

=item ReadResponseContent( [$timeout] )

Attempts to read a response from the connection, delimited by the null
character within the timeout. (Note that the content returned should
*NOT* include the terminating null character.)

=cut

sub ReadResponseContent() { die( "Unimplemented virtual function!" ) }

=pod

=item WriteRequestContent( $content )

Writes $content to the connection, adding a terminating null character
delimiter.  Returns the number of bytes written or undef if there was
an error.

=cut

sub WriteRequestContent() { die( "Unimplemented virtual function!" ) }

=pod

=item Connect()

Connects to the server specified on transport layer construction.
Returns a boolean indicating success or failure.

=cut

sub Connect() { die( "Unimplemented virtual function!" ) }

=pod

=item Disconnect()

Severs the connection with the server.  Returns a boolean indicating
success or failure.

=cut

sub Disconnect() { die( "Unimplemented virtual function!" ) }

=pod

=back

=back

=over 4

=item Server Personality

=over 4

=cut

=pod

=item IsServer()

Returns a boolean value indicating whether the transport is in the
'Server' personality.

=cut

sub IsServer() { die( "Unimplemented virtual function!" ) }

=pod

=item GetNextRequestingClient()

Returns a unique identifier for the next client with a pending request.
This identifier will be used at higher levels for reading the request
content.
  
This method should also reap any disconnected clients.

=cut

sub GetNextRequestingClient() { die( "Unimplemented virtual function!" ) }

=pod

=item ReadRequestContent( $clientId )

Read and return the content of a request from the client specified
by the given client id.
  
If there was an error or the client was disconnected, return undef.

=cut

sub ReadRequestContent() { die( "Unimplemented virtual function!" ) }

=pod

=item WriteResponseContent( $clientId, $content )

Write $content (adding a terminating null character) to the client
specified by the given client id.
  
Returns a boolean indicating success or failure.

=cut

sub WriteResponseContent() { die( "Unimplemented virtual function!" ) }

=pod

=item Listen()

Begin listening for incoming connections.  

=cut

sub Listen() { die( "Unimplemented virtual function!" ) }

=pod

=back

=back

=head1 SUPPORTED TRANSPORT LAYERS

=over 4

=item TCP

=back


=cut

1;
