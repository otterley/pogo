#!/usr/bin/env perl -w

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use common::sense;

use Test::More 'no_plan';

use Data::Dumper;
use FindBin qw($Bin);
use JSON;
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use YAML::XS qw(LoadFile);
use Sys::Hostname qw(hostname);

use lib "$Bin/lib";
use lib "$Bin/../lib";

use Pogo::Engine;
use Pogo::Engine::Job;
use Pogo::Engine::Store qw(store);

use PogoTester qw(derp);
ok( my $pt = PogoTester->new(), "new pt" );

chdir($Bin);

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

my $js = JSON->new;
my $t;

# start pogo-dispatcher
my $pid;
ok( $pid = $pt->start_dispatcher, "start dispatcher $pid" );

eval {

  my $conf;
  $conf = LoadFile("$Bin/conf/dispatcher.conf");
  ok( !$@, "loadconf" );

  # ping
  $t = $pt->dispatcher_rpc( ["ping"] );
  ok( $t->[1]->[0] == 0xDEADBEEF, 'ping' )
    or print Dumper $t;

  # stats
  $t = $pt->dispatcher_rpc( ["stats"] );
  ok( $t->[1]->[0]->{hostname} eq hostname(), 'stats' )
    or print Dumper $t;

  # ensure no workers are connected
  foreach my $dispatcher ( @{ $t->[1] } )
  {
    ok( exists $dispatcher->{workers_idle}, "exists workers_idle" );
    ok( exists $dispatcher->{workers_busy}, "exists workers_busy" );
    ok( $dispatcher->{workers_idle} == 0,   "zero workers_idle" );
    ok( $dispatcher->{workers_busy} == 0,   "zero workers_busy" );
  }

  # loadconf
  my $conf_to_load = LoadFile("$Bin/conf/constraints.test.yaml");
  $t = $pt->dispatcher_rpc( [ "loadconf", $conf_to_load ] )
    or print Dumper $t;

  # get the store up
  ok( Pogo::Engine::Store->init( $conf ), "store up" ); 

  # start a job
  my %job1 = (
    user      => 'test',
    run_as    => 'test',
    command   => 'echo job1',
    target    => [ 'foo.example.com', ],
    namespace => 'example',
    password  => 'foo',
    timeout   => 1800,
    job_timeout => 1800,
  );

  my $job = Pogo::Engine::Job->new( \%job1 );

  print Dumper $job;

};

# stop
ok( $pt->stop_dispatcher, 'stop dispatcher' );

1;

