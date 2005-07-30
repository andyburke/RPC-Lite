package RPC::Lite::Response;

use strict;
use Carp;
use Data::Dumper;

sub new
{
  my ( $class, $data ) = @_;

  my $self = bless {}, $class;
  $self->Result($data);

  return $self;
}

sub Result { $_[0]->{result} = $_[1] if @_ > 1; $_[0]->{result} }
sub Error  { return undef }
sub Id     { $_[0]->{id}     = $_[1] if @_ > 1; $_[0]->{id} }

1;
