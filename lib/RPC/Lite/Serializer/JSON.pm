package RPC::Lite::Serializer::JSON;

use strict;

use RPC::Lite::Request;
use RPC::Lite::Response;
use RPC::Lite::Notification;
use RPC::Lite::Error;

use JSON;

use Data::Dumper;

our $DEBUG = $ENV{DEBUG_SERIALIZER};

sub new
{
  my $class = shift;
  my $self = {};
  bless $self, $class;
}

sub Serialize
{
  my $self = shift;
  my $object = shift;
  
  my $type = ref($object);
  
  # plain perl data structures...
  if(!defined($type))
  {
    # no-op
  }
  elsif($type eq 'HASH')
  {
    # no-op
  }
  elsif($type eq 'ARRAY')
  {
    # no-op
  }
  elsif($type eq 'RPC::Lite::Request')
  {
    # effectively 'unbless' this thing
    $object =
      {
        jsonclass => $type,
        method    => $object->{method},
        params    => $object->{params}, # assume simple types, could recurse to attempt to throw real objects over the wire
        id        => $object->{id},
      };
  }
  elsif($type eq 'RPC::Lite::Response')
  {
    $object =
      {
        jsonclass => $type,
        result    => $object->{result}, # assume simple types
        error     => $object->{error},
        id        => $object->{id},
      };
  }
  elsif($type eq 'RPC::Lite::Notification')
  {
    $object =
      {
        jsonclass => $type,
        params    => $object->{params}, # assume simple types
        method    => $object->{method},
        id        => $object->{id},     # will be undef
      };
  }
  elsif($type eq 'RPC::Lite::Error')
  {
    $object =
      {
        jsonclass => $type,
        result    => $object->{result}, # undef
        error     => $object->{error},
        id        => $object->{id},
      };
  }
  else # try our best
  {
    # unbless w/ Data::Structure::Util?
  }

  $self->SanitizeData(\$object);
  my $data = objToJson($object);

  $self->_Debug('Serializing', Dumper($object), $data) if($DEBUG);

  return $data;
}

sub Deserialize
{
  my $self = shift;
  my $data = shift;

  length($data) or return undef;
  
  my $object = jsonToObj($data);
  my $result = $object;

  if(defined($object->{jsonclass}))
  {
    my $type = delete $object->{jsonclass};
    
    if($type eq 'RPC::Lite::Request')
    {
      $result = $type->new($object->{method}, $object->{params});
      $result->Id($object->{id});
    }
    elsif($type eq 'RPC::Lite::Response')
    {
      $result = $type->new($object->{result});
      $result->Id($object->{id});
    }
    elsif($type eq 'RPC::Lite::Notification')
    {
      $result = $type->new($object->{method}, $object->{params});
    }
    elsif($type eq 'RPC::Lite::Error')
    {
      $result = $type->new($object->{error});
      $result->Id($object->{id});
    }
  }

  $self->_Debug('Deserializing', $data, Dumper($result)) if($DEBUG);
    
  return $result;
}

sub SanitizeData
{
  my $self = shift;
  my $dataRef = shift;

  my $type = ref($$dataRef);

  if(length($type) && !($type eq 'HASH' or $type eq 'ARRAY'))
  {
    my $newType = 'HASH'; # just try a hash, screw people w/ their silly arrays
    warn("WARNING: Re-blessing: [$type] as [$newType]");
    bless $$dataRef, $newType;
  }
  elsif($type eq 'ARRAY')
  {
    foreach my $element (@{$$dataRef})
    {
      $self->SanitizeData(\$element);
    }
  }
  elsif($type eq 'HASH')
  {
    foreach my $key (keys %{$$dataRef})
    {
      $self->SanitizeData(\$$dataRef->{$key});
    }
  }

  return $dataRef;
}

sub _Debug
{
  my $self = shift;
  my $action = shift;
  my $input = shift;
  my $output = shift;

  print qq{
    $action
    =================================================================================

      input:
         
        $input
         
      output:
       
        $output
      
      =================================================================================
    
  };
}

1;
