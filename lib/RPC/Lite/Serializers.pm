# DOCUMENTATION-ONLY PACKAGE
package RPC::Lite::Serializers

=pod

=head1 NAME

RPC::Lite::Serializers -- A list of supported serializers.

=head1 NOTE

RPC::Lite::Servers automatically instantiate any of the supported serializers
as necessary to communicate with clients.

=head1 SUPPORTED SERIALIZERS

=over 4

=item JSON (client default)

"JSON (JavaScript Object Notation) is a lightweight data-interchange format.
It is easy for humans to read and write.  It is easy for machines to parse
and generate. It is based on a subset of the JavaScript Programming Language,
Standard ECMA-262 3rd Edition - December 1999."
  -- http://www.json.org/

=item XML

"Extensible Markup Language (XML) is a simple, very flexible text format
derived from SGML (ISO 8879). Originally designed to meet the challenges
of large-scale electronic publishing, XML is also playing an increasingly
important role in the exchange of a wide variety of data on the Web and elsewhere."
  -- http://www.w3.org/XML/

=item Null

The Null serializer is for communicating with native perl RPC::Lite servers
on the same machine.  It does nothing (and is largely untested, its use is
not currently recommended unless you are a developer wishing to improve it).

=back 

=cut

1;