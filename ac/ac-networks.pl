#!/usr/bin/perl

use lib 'include';

use junos;
use LWP::Simple;
use JSON::XS;
use Data::Dumper;
use strict;
use warnings;
use experimental 'smartmatch';
use Net::IP;

my $apiswitches = "http://gondul.lan.sdok.no/api/public/switches";
my $apiswitchesmanagement = "http://gondul.lan.sdok.no/api/read/switches-management";
my $apinetworks = "http://gondul.lan.sdok.no/api/read/networks";

my $junos_username = "lcs";
my $junos_password = "<PASSWORD>";

my $switchesjson = get( $apiswitches );
die "Could not get $apiswitches!" unless defined $switchesjson;

my $managementsjson = get( $apiswitchesmanagement );
die "Could not get $apiswitchesmanagement!" unless defined $managementsjson;

my $networksjson = get( $apinetworks );
die "Could not get $apinetworks!" unless defined $networksjson;

my $switchesmanagement = decode_json($managementsjson)->{'switches'};
my $switches = decode_json($switchesjson)->{'switches'};

my $networks = decode_json($networksjson);

for my $network ($networks->{'networks'}) {
  for my $network_name (keys(%$network)) {
    my $val = $network->{$network_name};
    if(defined($val->{'routing_point'})){
      my $coremgmt = $switchesmanagement->{$val->{'routing_point'}};
      my $core = $switches->{$val->{'routing_point'}};
      print $network_name . "\n";
      #print Dumper $val;
      #print Dumper $coremgmt;
      my @nettags = $val->{'tags'};
      if("ignore-ac" ~~ @nettags) { next; }
      my @coretags = $core->{'tags'};
      my $ipv4 = new Net::IP ($val->{"subnet4"}) or die (Net::IP::Error());
      my $ipv6 = new Net::IP ($val->{'subnet6'}) or die (Net::IP::Error());
      print Dumper @nettags;
      if("junos" ~~ @coretags) {
        my $distro = junos->connect(ip => $coremgmt->{'mgmt_v4_addr'}, username => $junos_username, password => $junos_password,'hostname' => $coremgmt->{'sysname'});
        $distro->create_vlan(vlan => $network_name, vlan_id => $val->{"vlan"}, ipv4_gw => $val->{"gw4"}, ipv6_gw => $val->{"gw6"}, ipv4_cidr => $ipv4->prefixlen(), ipv6_cidr => $ipv6->prefixlen());
        #$distro->logout();
      }
    }
  }
}