import requests
import json
import pprint
import os
import ipaddress
import re

#Settings to be changed before use
apinetworksurl = 'http://gondul.lan.sdok.no/api/read/networks'
zonename = 'lan.sdok.no'
subnet4file = '/usr/local/etc/kea/subnet4.json'
subnet6file = '/usr/local/etc/kea/subnet6.json'

# Do not look down here :)
r = requests.get(apinetworksurl)
networks = r.json()['networks'].items()

subnet4 = []
subnet6 = []

for name,data in networks:
        fqdn = name+'.'+zonename
        tags = data['tags']
        if 'dhcp' not in tags:
                continue
        if(data['subnet4']):
                ipv4 = ipaddress.ip_network(data['subnet4'])
                #We should check gondul and remove the IPs in use for switches # Or netbox?
                r = re.compile("reserved_first*")
                if (list(filter(r.match, tags))):
                        first = list(ipv4.hosts())[int(re.search(r'\d+', list(filter(r.match, tags))[0]).group())]
                else:
                        first = list(ipv4.hosts())[2]
                r = re.compile("reserved_last*")
                if (list(filter(r.match, tags))):
                        last = list(ipv4.hosts())[-int(re.search(r'\d+', list(filter(r.match, tags))[0]).group())-1]
                else:
                        last = list(ipv4.hosts())[-1]
                pool = {'pool': str(first)+'-'+str(last)}
                options = []
                if(data['gw4']):
                        options.append({'name': 'routers','data':data['gw4']})
                options.append({'name':'domain-name','data':fqdn})
                options.append({'name':'domain-search','data':fqdn})
                subnet = {'subnet':data['subnet4'], 'pools': [pool], 'option-data': options}
                subnet4.append(subnet)
        if(data['subnet6']):
                ipv6 = ipaddress.ip_network(data['subnet6'])
                pool = {'pool': str(ipv6.network_address)+'100-'+str(ipv6.network_address)+'ffff'}
                options = []
                options.append({'name':'domain-search','data':fqdn})
                interface = ''
                if 'localdhcp' in tags:
                        interface = 'ens160'
                        subnet = {'subnet':data['subnet6'], 'pools': [pool], 'option-data': options, 'interface': interface}
                else:
                        subnet = {'subnet':data['subnet6'], 'pools': [pool], 'option-data': options}
                subnet6.append(subnet)

print(subnet4)
print(subnet6)

if(subnet4):
        with open(subnet4file, 'w') as outfile:
                json.dump(subnet4, outfile, sort_keys=True, indent=4, separators=(',', ': '))
if(subnet6):
        with open(subnet6file, 'w') as outfile:
                json.dump(subnet6, outfile, sort_keys=True, indent=4, separators=(',', ': '))
