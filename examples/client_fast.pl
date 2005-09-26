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

my $fastResult;

$fastResult = $client->Request( 'FastMethod' );
print "FastMethod 1:\n  $fastResult\n\n";

$fastResult = $client->Request( 'FastMethod' );
print "FastMethod 2:\n  $fastResult\n\n";

$fastResult = $client->Request( 'FastMethod' );
print "FastMethod 3:\n  $fastResult\n\n";

print "sleeping 10 seconds\n";
sleep(10);

$fastResult = $client->Request( 'FastMethod' );
print "FastMethod 4:\n  $fastResult\n\n";
