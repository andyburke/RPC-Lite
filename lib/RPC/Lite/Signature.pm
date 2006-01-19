package RPC::Lite::Signature;

use strict;
use Carp;
use Data::Dumper;

sub new
{
  my $class = shift;
  my $data = shift;

  my $self = bless {}, $class;

  $self->FromString($data);

  return $self;
}

sub MethodName       { $_[0]->{methodname} = $_[1] if @_ > 1; $_[0]->{methodname} }
sub ReturnType       { $_[0]->{returntype} = $_[1] if @_ > 1; $_[0]->{returntype} }
sub ArgumentTypeList { $_[0]->{argumenttypelist} = $_[1] if @_ > 1; $_[0]->{argumenttypelist} }

sub AsString
{
  my $self = shift;

  return $self->MethodName . "=" . $self->ReturnType . ":" . join(',', @{$self->ArgumentTypeList});
}

sub FromString
{
  my $self = shift;
  my $data = shift;

  $data =~ s/\s+//g; # remove whitespace

  my ($methodName, $returnType, $argumentTypeListString) = $data =~ /^(.*?)=(.*?):(.*)$/;
  my @argumentTypeList = split(/,/, $argumentTypeListString);

  $self->MethodName($methodName);
  $self->ReturnType($returnType);
  $self->ArgumentTypeList(\@argumentTypeList);

}
1;
