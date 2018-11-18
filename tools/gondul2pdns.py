import requests
import json
import pprint
import os
from pdns import PowerDNS

#Settings to be changed before use
apiswitchmanagementurl = 'http://192.168.88.224/api/read/switches-management'
tempfile = 'temp.json'
pdnsapiurl = 'http://10.0.1.2:8081/api/v1'
pdnsapikey = 'fun'
zonename = 'lan.sdok.no.'

r = requests.get(apiswitchmanagementurl)
switches = r.json()['switches'].items()
new = {}
old = {}
pdns = PowerDNS(pdnsapiurl,pdnsapikey)
rrsets = []

if(os.stat(tempfile).st_size != 0):
        with open(tempfile) as data_file:
                old = json.load(data_file)

for name,data in switches:
        fqdn = name+'.'+zonename
        if name in old:
                # Exists
                if(old[name]['mgmt_v4_addr'] != data['mgmt_v4_addr']):
                        if(data['mgmt_v4_addr'] != None):
                                print(name+': New IPv4 found, will update DNS')
                                record = {'content':data['mgmt_v4_addr'], 'disabled': False,'type':'A'}
                                rrset = {'name':fqdn, 'changetype':'replace', 'type':'A', 'records':[record], 'ttl':900}
                                rrsets.append(rrset)
                        else:
                                print(name+': Blank IPv4 found, removing from DNS')
                                rrset = {'name':fqdn, 'changetype':'delete', 'type':'A', 'ttl':900}
                                rrsets.append(rrset)

                if(old[name]['mgmt_v6_addr'] != data['mgmt_v6_addr']):
                        if(data['mgmt_v6_addr'] != None):
                                print(name+': New IPv6 found, will update DNS')
                                record = {'content':data['mgmt_v6_addr'], 'disabled': False,'type':'AAAA'}
                                rrset = {'name':fqdn, 'changetype':'replace', 'type':'AAAA', 'records':[record], 'ttl':900}
                                rrsets.append(rrset)
                        else:
                                print(name+': Blank IPv6 found, removing from DNS')
                                rrset = {'name':fqdn, 'changetype':'delete', 'type':'AAAA', 'ttl':900}
                                rrsets.append(rrset)
        else:
                # New
                if(data['mgmt_v4_addr'] != None):
                        record = {'content':data['mgmt_v4_addr'], 'disabled': False,'type':'A'}
                        rrset = {'name':fqdn, 'changetype':'replace', 'type':'A', 'records':[record], 'ttl':900}
                        rrsets.append(rrset)
                if(data['mgmt_v6_addr'] != None):
                        record = {'content':data['mgmt_v6_addr'], 'disabled': False,'type':'AAAA'}
                        rrset = {'name':fqdn, 'changetype':'replace', 'type':'AAAA', 'records':[record], 'ttl':900}
                        rrsets.append(rrset)
                print(name+': New switch found, will add to DNS')
        new[name] = data

# Update powerdns
if rrsets:
        print(json.dumps(rrsets))
        print(pdns.set_zone_records(zonename,rrsets))

with open(tempfile, 'w') as outfile:
        json.dump(new, outfile)
