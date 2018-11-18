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
use Net::FTP;
use Mtik;
use MtikAC;

my $apiswitches = "http://gondul.lan.sdok.no/api/public/switches";
my $apiswitchesmanagement = "http://gondul.lan.sdok.no/api/read/switches-management";

my $junos_username = "lcs";
my $junos_password = "<PASSWORD>";

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
    if("new" ~~ @tags) {
      if("dlink" ~~ @tags) {

        my $switchmgmt = $switchesmanagement->{$switch_name};
        my $distromgmt = $switchesmanagement->{$switchmgmt->{'distro_name'}};

        my $distro_name = $switchmgmt->{'distro_name'};
        print Dumper $distromgmt;
        print Dumper $switchmgmt;
        my $distro_ip = $distromgmt->{'mgmt_v4_addr'};
        my $switch_name = $switch_name;
        my $connected_port = $switchmgmt->{'distro_phy_port'};
        my $switch_model = "dgs24";

        my $distro = junos->connect(ip => $distro_ip, username => $junos_username, password => $junos_password,'hostname' => $distro_name);

        # 1 - Set vlan on port to dlink-ac config network
        #$distro->delete_interface(port => $connected_port);
        $distro->set_vlan(port => $connected_port, vlan => 'dlink-ac', 'desc' => $switch_name);

        #sleep(5);

        # 2 - Checks if port is up
        if ($distro->portstatus(port=>$connected_port) == 0) {
          print "PORT IS NOT UP, NEXT SWITCH! \n";
          $distro->delete_interface(port => $connected_port);
          next;
        }

        # 3 - Pings the distro gateway
        my $respond = stuff->ping(ip => $switch_model,tryes => "35", gw => 1);

        if ($respond == 0) {
          print "\n The port $connected_port on $distro_name is not up, or there is a routing problem\n";
          $distro->delete_interface(port => $connected_port);
          next;
        }

        # 4 - Ping the default IP of the switch
        $respond = stuff->ping(ip => $switch_model,tryes => "15", gw => 0);
        if ($respond == 0) {
          print "No able to ping $switch_name, check that the switch is connected and in default config\n";
          $distro->delete_interface(port => $connected_port);
          next;
        }

        # 5 - Connect to the dlink and do our magic
        my $dlink = dlink->connect(ip => "10.90.90.90",username => "admin",password => "admin", name => $switch_name);
        $dlink->setIP(ip => "10.90.90.90", gateway => "10.90.90.1", subnetmask => "255.255.255.0");
        print $dlink->getHWversion();
        my $switch_version = $dlink->getHWversion();
        if($switch_version eq "C1") {
          stuff->log(message => "HW version C1", switch => $switch_name);
          $dlink->sendConfig(tftp => "10.90.90.2",file => "C1.bin");
        }
        elsif($switch_version eq "B1") {
          stuff->log(message => "HW version B1", switch => $switch_name);
          $dlink->sendConfig(tftp => "10.90.90.2",file => "B1.bin");
        }
        else {
          print("Switch is not supported $switch_version, quit");
          $distro->delete_interface(port => $connected_port);
          next;
        }
        print("Sending config from 10.90.90.2");
        sleep(7);
        $dlink->close;
        undef $dlink;
        print "The switch should now reboot, lets wait \n";
        sleep(2);
        $respond = stuff->ping(ip => "10.90.90.90",tryes => "120");
        if ($respond == 0)
        {
          print "No able to ping $switch_name, the switch is not up after config push \n";
          $distro->delete_interface(port => $connected_port);
          next;
        }
        print "Switch is back online, we now set password then new IP \n";
        $dlink = dlink->connect(ip => "10.90.90.90",username => "admin",password => "admin", name => $switch_name);
        $dlink->setPassword(password => $dlink_password);

        $dlink->setIP(ip => $switchmgmt->{'mgmt_v4_addr'}, gateway => $switchmgmt->{'mgmt_v4_gw'}, subnetmask => "255.255.255.224");

        sleep(5);
        $dlink->close;

        # 6 - Set vlan on port to dlink-ac config network

        $distro->delete_interface(port => $connected_port);
        $distro->set_vlan(port => $connected_port, vlan => $switch_name, 'desc' => $switch_name);

        #$distro->logouti();

      }elsif("mtik" ~~ @tags) {
        my $switchmgmt = $switchesmanagement->{$switch_name};
        my $distromgmt = $switchesmanagement->{$switchmgmt->{'distro_name'}};

        my $distro_name = $switchmgmt->{'distro_name'};
        print Dumper $distromgmt;
        print Dumper $switchmgmt;
        my $distro_ip = $distromgmt->{'mgmt_v4_addr'};
        my $switch_name = $switch_name;
        my $connected_port = $switchmgmt->{'distro_phy_port'};
        my $switch_model = "mtik";

        my $distro = junos->connect(ip => $distro_ip, username => $junos_username, password => $junos_password,'hostname' => $distro_name);

        # 1 - Set vlan on port to dlink-ac config network
        $distro->set_vlan(port => $connected_port, vlan => 'dlink-ac', 'desc' => $switch_name);

        # 2 - Checks if port is up
        if ($distro->portstatus(port=>$connected_port) == 0) {
          print "PORT IS NOT UP, NEXT SWITCH! \n";
          $distro->delete_interface(port => $connected_port);
          next;
        }

        # 3 - Pings the distro gateway
        my $respond = stuff->ping(ip => $switch_model,tryes => "35", gw => 1);

        if ($respond == 0) {
          print "\n The port $connected_port on $distro_name is not up, or there is a routing problem\n";
          $distro->delete_interface(port => $connected_port);
          next;
        }

        # 4 - Ping the default IP of the switch
        $respond = stuff->ping(ip => $switch_model,tryes => "15", gw => 0);
        if ($respond == 0) {
          print "No able to ping $switch_name, check that the switch is connected and in default config\n";
          $distro->delete_interface(port => $connected_port);
          next;
        }

        #Connect the API
        $Mtik::debug = 2;
        my($mtik_host) = '192.168.88.1';
        my($mtik_username) = 'admin';
        my($mtik_password) = '';
        print "Logging in to Mtik: $mtik_host\n";
        Mtik::login($mtik_host,$mtik_username,$mtik_password,"8728");
        #Connect the FTP
        my $ftp = Net::FTP->new("192.168.88.1", Debug => 0)
        or die "Cannot connect to mtik: $@";
        $ftp->login("admin",'')
        or die "Cannot login ", $ftp->message;
        $ftp->binary;
        #Check if switch is running an old firmware
        my %attrs;
        my %queries;
        my($retval,@results) = Mtik::mtik_query("/system/package/print", \%attrs, \%queries);
        if($results[0]{version} ne "6.40.5") {
          print "Not correct OS, running: ".$results[0]{version} ."\n";
          $ftp->put("/home/sdok/lcs/root/LCS/AC/mikrotik-firmware/routeros-mipsbe-6.40.5.npk", "routeros-mipsbe-6.40.5.npk") or die "put failed: " . $ftp->message;
          print "Uploaded \n"
        }
        else {
          print "Running $results[0]{version}";
        }
        #Upload the config, then restart
        $ftp->put("/home/sdok/lcs/root/LCS/AC/mikrotik-config/sw-$switch_name.rsc", "config.rsc") or die "put failed: " . $ftp->message;

        my %attrs1;
        $attrs1{"no-defaults"} = "yes";
        $attrs1{"run-after-reset"} = "config.rsc";

        Mtik::mtik_cmd("/system/reset-configuration", \%attrs1);

        Mtik::logout;

        print "Done with mtik";

        # 6 - Set vlan on port to dlink-ac config network

        $distro->delete_interface(port => $connected_port);
        $distro->set_vlan(port => $connected_port, vlan => $switch_name, 'desc' => $switch_name);

      }
    }
  }
}