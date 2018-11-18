#!/usr/bin/perl
package MtikAC;
use Net::Netmask;
use Net::FTP;
use Data::Dumper;
use LWP::Simple;
use JSON::XS;

# ALL IS NOT UPDATED TO THE GONDUL WORLD!

sub getResources {
  my $class = shift;
  my %args = @_;
  my $dbh = DBI->connect("dbi:mysql:$lcs::config::db_name",$lcs::config::db_username,$lcs::config::db_password) or die "Connection Error: $DBI::errstr\n";
  my $sql = "SELECT ip,name FROM switches WHERE switches.model = 'mtik'";
  my $sth = $dbh->prepare($sql);
  $sth->execute or die "SQL Error: $DBI::errstr\n";

  while (my $ref = $sth->fetchrow_hashref()) {
    $Mtik::debug = 2;
    my($mtik_host) = $ref->{'ip'};
    my($mtik_username) = $lcs::config::mtik_user;
    my($mtik_password) = $lcs::config::mtik_pass;
    print "Logging in to Mtik: $mtik_host ".$ref->{"name"}."\n";
    Mtik::login($mtik_host,$mtik_username,$mtik_password,"8728");
    #Check if switch is running an old firmware
    my %attrs;
    my %queries;
    my($retval,@results) = Mtik::mtik_query("/system/resource/print", \%attrs, \%queries);
    #print Dumper $results[0]{"cpu-load"};
    print "Mem: $results[0]{'used-memory'} \n";
    Mtik::logout;
  }
}

sub getTemp {
  my $class = shift;
  my %args = @_;
  my $dbh = DBI->connect("dbi:mysql:$lcs::config::db_name",$lcs::config::db_username,$lcs::config::db_password) or die "Connection Error: $DBI::errstr\n";
  my $sql = "SELECT ip,name FROM switches WHERE switches.model = 'mtik'";
  my $sth = $dbh->prepare($sql);
  $sth->execute or die "SQL Error: $DBI::errstr\n";

  while (my $ref = $sth->fetchrow_hashref()) {
    $Mtik::debug = 2;
    my($mtik_host) = $ref->{'ip'};
    my($mtik_username) = $lcs::config::mtik_user;
    my($mtik_password) = $lcs::config::mtik_pass;
    print "Logging in to Mtik: $mtik_host ".$ref->{"name"}."\n";
    Mtik::login($mtik_host,$mtik_username,$mtik_password,"8728");
    #Check if switch is running an old firmware
    my %attrs;
    my %queries;
    my($retval,@results) = Mtik::mtik_query("/system/health/print", \%attrs, \%queries);
    print "Temp: $results[0]{temperature} \n";
    Mtik::logout;
  }
}

sub checkFirmware {
  my $class = shift;
  my %args = @_;
  my $dbh = DBI->connect("dbi:mysql:$lcs::config::db_name",$lcs::config::db_username,$lcs::config::db_password) or die "Connection Error: $DBI::errstr\n";
  my $sql = "SELECT ip,name FROM switches WHERE switches.model = 'mtik'";
  my $sth = $dbh->prepare($sql);
  $sth->execute or die "SQL Error: $DBI::errstr\n";

  while (my $ref = $sth->fetchrow_hashref()) {
    $Mtik::debug = 2;
    my($mtik_host) = $ref->{'ip'};
    my($mtik_username) = $lcs::config::mtik_user;
    my($mtik_password) = $lcs::config::mtik_pass;
    print "Logging in to Mtik: $mtik_host ".$ref->{"name"}."\n";
    Mtik::login($mtik_host,$mtik_username,$mtik_password,"8728");
    #Check if switch is running an old firmware
    my %attrs;
    my %queries;
    my($retval,@results) = Mtik::mtik_query("/system/package/print", \%attrs, \%queries);
    if($results[0]{version} ne $lcs::config::mtik_version) {
      print "Not correct OS, running: ".$results[0]{version} ."\n";
      #Connect the FTP
      my $ftp = Net::FTP->new($ref->{'ip'}, Debug => 0)
      or die "Cannot connect to mtik: $@";
      $ftp->login("admin",'<REMOVED>')
      or die "Cannot login ", $ftp->message;
      $ftp->binary;
      $ftp->put("/lcs/AC/mikrotik-firmware/routeros-mipsbe-6.33.npk", "routeros-mipsbe-6.33.npk") or die "put failed: " . $ftp->message;
    }
    else {
      print "Running $results[0]{version} \n";
    }
    Mtik::logout;
  }
}

sub setHostname {
  my $class = shift;
  my %args = @_;

  my $apiswitches = "http://gondul.lan.sdok.no/api/public/switches";
  my $apiswitchesmanagement = "http://gondul.lan.sdok.no/api/read/switches-management";

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
      if("mtik" ~~ @tags) {
        my $switchmgmt = $switchesmanagement->{$switch_name};

        $Mtik::debug = 2;
        my($mtik_host) = $switchmgmt->{'mgmt_v4_addr'};
        my($mtik_username) = "admin";
        my($mtik_password) = "<REMOVED>";
        print "Logging in to Mtik: $switch_name \n";
        Mtik::login($mtik_host,$mtik_username,$mtik_password,"8728");
        my %attrs1;
        $attrs1{"name"} = $switch_name;
        Mtik::mtik_cmd("/system/identity/set", \%attrs1);
        Mtik::logout;
      }
    }
  }
}

sub enableIPv6 {
  my $class = shift;
  my %args = @_;

  my $apiswitches = "http://gondul.lan.sdok.no/api/public/switches";
  my $apiswitchesmanagement = "http://gondul.lan.sdok.no/api/read/switches-management";

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
      if("mtik" ~~ @tags) {
        my $switchmgmt = $switchesmanagement->{$switch_name};

        $Mtik::debug = 2;
        my($mtik_host) = $switchmgmt->{'mgmt_v4_addr'};
        my($mtik_username) = "admin";
        my($mtik_password) = "<REMOVED>";
        print "Logging in to Mtik: $switch_name \n";
        Mtik::login($mtik_host,$mtik_username,$mtik_password,"8728");
        my($retval,@results) = Mtik::mtik_query("/system/package/print", \%attrs, \%queries);
        for my $package (@results) {
          if($package->{'name'} eq "ipv6") {
            if($package->{'disabled'} eq "true") {
              print Dumper($package);
              Mtik::mtik_cmd("/system/package/enable/".$package->{'.id'});
              Mtik::mtik_cmd("/system/reboot");
            }
          }
        }
        Mtik::logout;
      }
    }
  }
}


sub setPassword {
  my $class = shift;
  my %args = @_;

  my $apiswitches = "http://gondul.lan.sdok.no/api/public/switches";
  my $apiswitchesmanagement = "http://gondul.lan.sdok.no/api/read/switches-management";

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
      if("mtik" ~~ @tags) {
        my $switchmgmt = $switchesmanagement->{$switch_name};
        $Mtik::debug = 2;
        my $mtik_username = 'admin';
        my $mtik_password  = '';
        print "Logging in to Mtik: $switchmgmt->{'mgmt_v4_addr'} \n";
        Mtik::login($switchmgmt->{'mgmt_v4_addr'},$mtik_username,$mtik_password,"8728");
        my %attrs1;
        $attrs1{"old-password"} = "";
        $attrs1{"new-password"} = "<removed>";
        $attrs1{"confirm-new-password"} = "<removed>";
        Mtik::mtik_cmd("/password", \%attrs1);
        Mtik::logout;
      }
    }
  }
}

sub create_config {
  my $class = shift;
  my %args = @_;

  my $apiswitches = "http://gondul.lan.sdok.no/api/public/switches";
  my $apiswitchesmanagement = "http://gondul.lan.sdok.no/api/read/switches-management";

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
        if("mtik" ~~ @tags) {

          my $switchmgmt = $switchesmanagement->{$switch_name};
          my $distromgmt = $switchesmanagement->{$switchmgmt->{'distro_name'}};

          $network_block = new Net::Netmask ($switchmgmt->{'subnet4'});
          my $ip_address = $switchmgmt->{'mgmt_v4_addr'};
          my $cidr = $network_block->bits();
          my $network = $network_block->base();
          my $gateway = $switchmgmt->{'mgmt_v4_gw'};
          my $password = "<removed>";
          my $snmp = "<removed>";
          my $pin = "1337";

          open(my $fh, '>', "/home/sdok/lcs/root/LCS/AC/mikrotik-config/sw-$switch_name.rsc");

          $config = <<"EOF";
/interface ethernet
set [ find default-name=ether2 ] master-port=ether1
set [ find default-name=ether3 ] master-port=ether1
set [ find default-name=ether4 ] master-port=ether1
set [ find default-name=ether5 ] master-port=ether1
set [ find default-name=ether6 ] master-port=ether1
set [ find default-name=ether7 ] master-port=ether1
set [ find default-name=ether8 ] master-port=ether1
set [ find default-name=ether9 ] master-port=ether1
set [ find default-name=ether10 ] master-port=ether1
set [ find default-name=ether11 ] master-port=ether1
set [ find default-name=ether12 ] master-port=ether1
set [ find default-name=ether13 ] master-port=ether1
set [ find default-name=ether14 ] master-port=ether1
set [ find default-name=ether15 ] master-port=ether1
set [ find default-name=ether16 ] master-port=ether1
set [ find default-name=ether17 ] master-port=ether1
set [ find default-name=ether18 ] master-port=ether1
set [ find default-name=ether19 ] master-port=ether1
set [ find default-name=ether20 ] master-port=ether1
set [ find default-name=ether21 ] master-port=ether1
set [ find default-name=ether22 ] master-port=ether1
set [ find default-name=ether23 ] master-port=ether1
set [ find default-name=ether24 ] master-port=ether1
set [ find default-name=sfp1 ] master-port=ether1 name=sfp1-slave-local
/snmp community
set [ find default=yes ] name=$snmp
/interface ethernet switch port
set 1 isolation-leakage-profile-override=2
set 2 isolation-leakage-profile-override=2
set 3 isolation-leakage-profile-override=2
set 4 isolation-leakage-profile-override=2
set 5 isolation-leakage-profile-override=2
set 6 isolation-leakage-profile-override=2
set 7 isolation-leakage-profile-override=2
set 8 isolation-leakage-profile-override=2
set 9 isolation-leakage-profile-override=2
set 10 isolation-leakage-profile-override=2
set 11 isolation-leakage-profile-override=2
set 12 isolation-leakage-profile-override=2
set 13 isolation-leakage-profile-override=2
set 14 isolation-leakage-profile-override=2
set 15 isolation-leakage-profile-override=2
set 16 isolation-leakage-profile-override=2
set 17 isolation-leakage-profile-override=2
set 18 isolation-leakage-profile-override=2
set 19 isolation-leakage-profile-override=2
set 20 isolation-leakage-profile-override=2
set 21 isolation-leakage-profile-override=2
set 22 isolation-leakage-profile-override=2
set 23 isolation-leakage-profile-override=2
/interface ethernet switch port-isolation
add forwarding-type=bridged port-profile=2 ports=ether1 protocol-type=dhcpv4 registration-status="" traffic-type="" type=dst
/ip address
add address=$ip_address/$cidr comment="default configuration" interface=ether1 network=$network
/ip route
add distance=1 gateway=$gateway
/lcd
set backlight-timeout=never default-screen=informative-slideshow read-only-mode=yes touch-screen=disabled
/lcd pin
set pin-number=$pin
/lcd screen
set 0 disabled=yes
set 1 disabled=yes
set 2 disabled=yes
/snmp
set enabled=yes
/system clock
set time-zone-name=Europe/Oslo
/system identity
set name=SWITCH
/system routerboard settings
set protected-routerboot=disabled
/tool romon port
set [ find default=yes ] cost=100 forbid=no interface=all secrets=""
/system package
disable advanced-tools
disable dhcp
disable hotspot
disable mpls
disable ppp
disable routing
disable wireless-cm2
disable wireless-fp
enable system
enable security
enable routeros-mipsbe
EOF
          print $fh $config;
          close $fh;
          print "done with $switch_name-\n";
        }
      }
    }
  }

}


1;