use strict;
use warnings;
use Net::Telnet::Cisco;

package ciscoconf;

my $session;

my $name;

sub connect {
  my $class = shift;
  my $self = bless {}, $class;
  my %args = @_;
  $session = Net::Telnet::Cisco->new(Host => $args{ip}, Timeout => 100);
  $session->login($args{username}, $args{password});

  if ($session->enable($args{enable_password}) ) {
  } else {
    warn "Can't enable: " . $session->errmsg;
  }
  $name = $args{hostname};
  return $self;
}

sub setup_port {
  my $self = shift;
  my %args = @_;
  #CLEAN THE ARP CACHE
  $session->cmd("clear arp-cache");
  #GO TO CONF MODE FOR THIS PORT
  $session->cmd("conf t");
  $session->cmd("default interface gigabit ".$args{port});
  $session->cmd("interface gigabit ".$args{port});
  $session->cmd("no shutdown");
  #TURN OFF SWITCHPORT
  $session->cmd("no switchport");
  #SET IP
  if($args{model} eq "mtik") {
    $session->cmd("ip address 192.168.88.2 255.255.255.0");
  } elsif($args{model} eq "dgs24") {
    $session->cmd("ip address 10.90.90.1 255.255.255.0");
  } else {
    die($args{model}." NOT SUPPORTED")
  }
  $session->cmd("desc CONFIG");
  #GO BACK TO START
  $session->cmd("exit");
  $session->cmd("exit");

  print $name.": port ". $args{port}. " set to CONFIG MODE \n";
}

sub createvlan_interface {
  my $self = shift;
  my %args = @_;
  #CREATE VLAN
  #GO TO CONF MODE
  $session->cmd("conf t");
  #CREATE VLAN
  $session->cmd("vlan $args{vlan}");
  $session->cmd("name $args{name}");
  $session->cmd("exit");
  #CREATE THE VLAN INTERFACE
  $session->cmd("interface vlan $args{vlan}");
  $session->cmd("no shut");
  $session->cmd("ip address $args{vlan} $args{subnet}");
  $session->cmd("desc $args{name}");
  $session->cmd("ip helper-address $args{helper}");
  $session->cmd("exit");
  $session->cmd("exit");
}

sub setvlan {
  my $self = shift;
  my %args = @_;
  #Set a port at a vlan
  #CLEAN THE ARP CACHE
  $session->cmd("clear arp-cache");
  #GO TO CONF MODE FOR THIS PORT
  $session->cmd("conf t");
  $session->cmd("default interface gigabit ".$args{port});
  $session->cmd("interface gigabit ".$args{port});
  #TURN ON SWITCHPORT AND MAKE MODE ACCESS
  $session->cmd("switchport");
  $session->cmd("switchport mode access");
  #SET PORT TO VLAN
  $session->cmd("switchport access vlan ".$args{vlan});
  #SET DESC AT PORT
  $session->cmd("desc ".$args{desc});
  #MAKE SURE THE PORT IS UP
  $session->cmd("no shutdown");
  #GO BACK TO START
  $session->cmd("exit");
  $session->cmd("exit");
  print $name.": port ". $args{port}. " set to vlan ".$args{vlan}."\n";
}

sub portstatus {
  my $self = shift;
  my %args = @_;

  my @cmd_output = $session->cmd("show ip interface brief gigabit $args{port}");

  if ($cmd_output[1] =~ /down/) {
    return 0;
  }
  return 1;
}

sub shut_port {
  my $self = shift;
  my %args = @_;

  $session->cmd("conf t");
  $session->cmd("interface gigabit $args{port}");
  $session->cmd("shut");
}

sub gateway_mikrotik {
  my $self = shift;
  my %args = @_;
  #$session->dump_log("telnet.txt");
  $session->print("telnet 192.168.88.1");

  $session->waitfor('/Login:/');
  $session->print("admin");
  $session->waitfor('/Password:/');
  $session->print("");
  #$session->waitfor('/Confirming configuration../');
  sleep(7);
  $session->print("");
  $session->waitfor('/\[admin.MikroTik] >/');
  $session->print("ip route add distance=1 gateway=192.168.88.2");
  $session->waitfor('/\[admin.MikroTik] >/');
  $session->print("quit");
}

1;