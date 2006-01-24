package RPC::Lite::SessionManager;

use strict;

sub Sessions         { $_[0]->{sessions}         = $_[1] if @_ > 1; $_[0]->{sessions} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my $self = {};
  bless $self, $class;

  $self->Sessions({});

  return $self;
}

sub Add
{
  my $self = shift;
  my $sessionId = shift;
  my $info = shift;
  
  $self->Sessions->{$sessionId} = $info;
}

sub Remove
{
  my $self = shift;
  my $sessionId = shift;

  return delete $self->Sessions->{$sessionId};
}
1;
