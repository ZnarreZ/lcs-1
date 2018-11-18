use strict;
use warnings;
use Net::Netconf::Manager;
use Data::Dumper;
use XML::Parser;

package junos;

use constant REPORT_SUCCESS => 1;
use constant REPORT_FAILURE => 0;
use constant STATE_CONNECTED => 1;
use constant STATE_LOCKED => 2;
use constant STATE_CONFIG_LOADED => 3;

my $jnx;

my $name;

sub graceful_shutdown
{
  my ($jnx, $state, $success) = @_;
  if ($state >= STATE_CONFIG_LOADED) {
    # We have already done an <edit-config> operation
    # - Discard the changes
    print "Discarding the changes made ...\n";
    $jnx->discard_changes();
    if ($jnx->has_error) {
      print "Unable to discard <edit-config> changes\n";
    }
  }

  if ($state >= STATE_LOCKED) {
    # Unlock the configuration database
    $jnx->unlock_config();
    if ($jnx->has_error) {
      print "Unable to unlock the candidate configuration\n";
    }
  }

  if ($state >= STATE_CONNECTED) {
    # Disconnect from the Netconf server
    $jnx->disconnect();
  }

  if ($success) {
    print "REQUEST succeeded !!\n";
  } else {
    print "REQUEST failed !!\n";
  }

  exit;
}

sub get_error_info
{
  my %error = @_;

  print "\nERROR: Printing the server request error ...\n";

  # Print 'error-severity' if present
  if ($error{'error_severity'}) {
    print "ERROR SEVERITY: $error{'error_severity'}\n";
  }
  # Print 'error-message' if present
  if ($error{'error_message'}) {
    print "ERROR MESSAGE: $error{'error_message'}\n";
  }

  # Print 'bad-element' if present
  if ($error{'bad_element'}) {
    print "BAD ELEMENT: $error{'bad_element'}\n\n";
  }
}


sub connect {
  my $class = shift;
  my $self = bless {}, $class;
  my %args = @_;
  my %deviceinfo = (
  'access' => 'ssh',
  'login' => $args{username},
  'password' => $args{password},
  'hostname' => $args{ip},
  );

  $jnx = new Net::Netconf::Manager(%deviceinfo);
  unless (ref $jnx) {
    print "ERROR: $args{hostname} ($args{ip}): failed to connect.\n";
  }
  print("Connected to ".$args{hostname});
  $name = $args{hostname};
  return $self;
}

sub delete_interface {
  my $self = shift;
  my %args = @_;

  my $interface = $args{port};

  my $config = '<configuration>
  <interfaces>
  <interface operation="delete">
  <name>'.$interface.'</name>
  </interface>
  </interfaces>
  </configuration>';

  print($config);

  $self->set_config(config => $config);
}

sub set_config {
  my $selv = shift;
  my %args = @_;
  my $config = $args{config};

  print "Locking configuration database ...\n";
  my %queryargs = ( 'target' => 'candidate' );
  $jnx->lock_config(%queryargs);
  if ($jnx->has_error) {
    print "ERROR: in processing request \n $jnx->{'request'} \n";
    graceful_shutdown($jnx, STATE_CONNECTED, REPORT_FAILURE);
  }

  %queryargs = ( 'target' => 'candidate', 'config' => $config );
  $jnx->edit_config(%queryargs);

  # See if you got an error
  if ($jnx->has_error) {
    print "ERROR: in processing request \n $jnx->{'request'} \n";
    # Get the error
    my $error = $jnx->get_first_error();
    get_error_info(%$error);
    # Disconnect
    graceful_shutdown($jnx, STATE_LOCKED, REPORT_FAILURE);
  }

  # Commit the changes
  print "Committing the <edit-config> changes ...\n";
  $jnx->commit();
  if ($jnx->has_error) {
    print "ERROR: Failed to commit the configuration.\n";
    graceful_shutdown($jnx, STATE_CONFIG_LOADED, REPORT_FAILURE);
  }

  # Unlock the configure again
  $jnx->unlock_config();

}

sub set_vlan {
  my $self = shift;
  my %args = @_;

  my $interface = $args{port};
  my $vlan = $args{vlan};

  my $config = '<configuration>
  <interfaces>
  <interface>
  <name>'.$interface.'</name>
  <unit>
  <name>0</name>
  <family>
  <ethernet-switching>
  <vlan>
  <members>'.$vlan.'</members>
  </vlan>
  </ethernet-switching>
  </family>
  </unit>
  </interface>
  </interfaces>
  </configuration>';

  print($config);

  $self->set_config(config => $config);
}

sub create_vlan {
  my $self = shift;
  my %args = @_;

  my $vlan = $args{vlan};
  my $vlan_id = $args{vlan_id};
  my $ipv4_gw = $args{ipv4_gw};
  my $ipv6_gw = $args{ipv6_gw};
  my $ipv4_cidr = $args{ipv4_cidr};
  my $ipv6_cidr = $args{ipv6_cidr};

  my $config = '
  <configuration>
  <vlans>
  <vlan>
  <name>'.$vlan.'</name>
  <vlan-id>'.$vlan_id.'</vlan-id>
  <l3-interface>vlan.'.$vlan_id.'</l3-interface>
  </vlan>
  </vlans>
  <interfaces>
  <interface>
  <name>vlan</name>
  <unit>
  <name>'.$vlan_id.'</name>
  <family>
  <inet>
  <address>
  <name>'.$ipv4_gw.'/'.$ipv4_cidr.'</name>
  </address>
  </inet>
  <inet6>
  <address>
  <name>'.$ipv6_gw.'/'.$ipv6_cidr.'</name>
  </address>
  </inet6>
  </family>
  </unit>
  </interface>
  </interfaces>
  <protocols>
  <router-advertisement>
  <interface>
  <name>vlan.'.$vlan_id.'</name>
  <prefix>
  <name>'.$ipv6_gw.'/'.$ipv6_cidr.'</name>
  </prefix>
  </interface>
  </router-advertisement>
  </protocols>
  </configuration>';

  print($config);

  $self->set_config(config => $config);
}

sub portstatus {
  my $self = shift;
  my %args = @_;

  my $query = "get_interface_information";
  my %queryargs = ('interface-name' => $args{port});
  $jnx->$query(%queryargs);

  if ($jnx->has_error) {
    print "ERROR: in processing request\n";
    # Get the error
    my $error = $jnx->get_first_error();
    $jnx->print_error_info(%$error);
    exit 1;
  }

  my $config= $jnx->get_dom();
  my $xpc = XML::LibXML::XPathContext->new($config);
  my $status=$xpc->findnodes('/*[local-name()="rpc-reply"]/*[local-name()="interface-information"]/*[local-name()="physical-interface"]/*[local-name()="oper-status"]');

  print $status;
  if($status =~ /up/){
    return 1;
  } else {
    return 0;
  }

}

sub logout {
  # Unlock the configuration database and
  # disconnect from the Netconf server
  print "Disconnecting from the Netconf server ...\n";
  graceful_shutdown($jnx, STATE_LOCKED, REPORT_SUCCESS);
}

1;
