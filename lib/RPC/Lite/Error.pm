package RPC::Lite::Error;

use strict;
use base qw(RPC::Lite::Response);


sub new
{
  my ($class, $data) = @_;

  my $self = bless {}, $class;
  $self->Error($data);

  return $self;
}

sub Result { return undef }
sub Error  { $_[0]->{error} = $_[1] if @_>1; $_[0]->{error} }

1;
