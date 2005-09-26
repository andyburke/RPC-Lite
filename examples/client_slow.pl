#!/usr/bin/perl
use strict;

use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use Data::Dumper;

my $client = RPC::Lite::Client->new(
                                     {
                                       Transport  => RPC::Lite::Transport::TCP->new( { Host => 'localhost', Port => 10000 } ),
                                       Serializer => RPC::Lite::Serializer::JSON->new(),
                                     }
                                   );    

my $slowResult = $client->Request( 'SlowMethod' );
print "SlowMethod:\n  $slowResult\n\n";

