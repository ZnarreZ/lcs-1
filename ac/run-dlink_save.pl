#!/usr/bin/perl
use LWP::Simple;
use JSON::XS;
use Data::Dumper;
use strict;
use warnings;
use experimental 'smartmatch';

use lib 'include';

use junos;
use stuff;
use dlink;

my $apiswitches = "http://gondul.lan.sdok.no:8080/api/public/switches";
my $apiswitchesmanagement = "http://gondul.lan.sdok.no:8080/api/read/switches-management";

my $dlink_password = "<PASSWORD>";

my $switchesjson = get( $apiswitches );
die "Could not get $apiswitches!" unless defined $switchesjson;

my $managementsjson = get( $apiswitchesmanagement );
die "Could not get $apiswitchesmanagement!" unless defined $managementsjson;

my $switchesmanagement = decode_json($managementsjson)->{'switches'};

my $switches = decode_json($switchesjson);
for my $switch ($switches->{'switches'}) {
  for my $switch_name (keys(%$switch)) {
    my $val = $switch->{$switch_name};
    my @tags = $val->{'tags'};
    if("dlink" ~~ @tags) {
      if("dlink" ~~ @tags) {

        my $switchmgmt = $switchesmanagement->{$switch_name};
        my $distromgmt = $switchesmanagement->{$switchmgmt->{'distro_name'}};

        my $distro_name = $switchmgmt->{'distro_name'};
        print Dumper $distromgmt;
        print Dumper $switchmgmt;

        print "Switch is back online, lets save \n";
        my $dlink = dlink->connect(ip => $switchmgmt->{'mgmt_v4_addr'},username => "admin",password => $dlink_password, name => $switch_name);
        $dlink->save();
        $dlink->close;

      }
    }
  }
}