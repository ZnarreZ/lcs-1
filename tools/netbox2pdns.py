import ipaddress
import pynetbox
from pdns import PowerDNS
import json
import netaddr

nb = pynetbox.api(
    'https://netbox.sdok.no',
    token='<REMOVED>'
)

base_dns_zone = 'lan.sdok.no'

pdnsapiurl = 'http://terra.lan.sdok.no:8081/api/v1'
pdnsapikey = '<REMOVED>'

pdns = PowerDNS(pdnsapiurl,pdnsapikey)

vms = nb.virtualization.virtual_machines.filter()
for vm in vms:
    print(vm)
    if vm.primary_ip4 is not None:
        print(vm.primary_ip4)
        ip = netaddr.IPNetwork(str(vm.primary_ip4)).ip
        subnet = ipaddress.ip_network(str(vm.primary_ip4), strict=False)
        print(subnet)
        prefix = nb.ipam.prefixes.get(q=str(subnet))
        print(prefix.vlan.name)
        fqdn = "{0}.{1}.{2}.".format(str(vm),str(prefix.vlan.name),base_dns_zone)
        record = {'content':str(ip), 'disabled': False,'type':'A'}
        rrset = {'name':fqdn, 'changetype':'replace', 'type':'A', 'records':[record], 'ttl':900}
        print(pdns.set_zone_records("{0}.{1}".format(str(prefix.vlan.name),base_dns_zone),[rrset]))

        record = {'content':fqdn, 'disabled': False,'type':'CNAME'}
        rrset = {'name':"{0}.{1}".format(str(vm),base_dns_zone), 'changetype':'replace', 'type':'CNAME', 'records':[fqdn], 'ttl':900}
        print(pdns.set_zone_records("{0}.{1}".format(str(prefix.vlan.name),base_dns_zone),[rrset]))

        if vm.primary_ip6 is not None:
            print(vm.primary_ip6)
            ip = netaddr.IPNetwork(str(vm.primary_ip6)).ip
            subnet = ipaddress.ip_network(str(vm.primary_ip6), strict=False)
            print(subnet)
            prefix = nb.ipam.prefixes.get(q=str(subnet))
            print(prefix.vlan.name)
            fqdn = "{0}.{1}.{2}.".format(str(vm),str(prefix.vlan.name),base_dns_zone)
            record = {'content':str(ip), 'disabled': False,'type':'AAAA'}
            rrset = {'name':fqdn, 'changetype':'replace', 'type':'AAAA', 'records':[record], 'ttl':900}
            print(pdns.set_zone_records("{0}.{1}".format(str(prefix.vlan.name),base_dns_zone),[rrset]))