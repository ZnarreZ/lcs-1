import csv
import requests
import json
import ipaddress
with open('switches.csv', newline='') as csvfile:
        switches = csv.reader(csvfile, delimiter=',', quotechar='|')
        for row in switches:
                gw4 = ipaddress.IPv4Network(row[1])[1].exploded
                gw6 = ipaddress.IPv6Network(row[2])[1].exploded
                switch4 = ipaddress.IPv4Network(row[1])[2].exploded
                switch6 = ipaddress.IPv6Network(row[2])[2].exploded
                data = json.dumps([{'sysname': row[0], 'distro_name': row[3], 'distro_phy_port': row[4], 'traffic_vlan': row[0], 'mgmt_vlan': row[0], 'mgmt_v4_addr': switch4, 'mgmt_v6_addr': switch6, 'community':'<removed>' , 'tags': '["dlink","simplesnmp"]'}])
                r = requests.post("http://gondul.lan.sdok.no/api/write/switch-update", data=data, headers={'content-type': 'application/json'})
                print(r.status_code, r.reason, data)

                data = json.dumps([{'sysname': row[0], 'subnet4': row[1], 'subnet6': row[2], 'gw4': gw4, 'gw6': gw6, 'routing_point': row[3], 'vlan': row[5], 'tags': '["dhcp", "clients"]'}])
                r = requests.post("http://gondul.lan.sdok.no/api/write/network-update", data=data, headers={'content-type': 'application/json'})
                print(r.status_code, r.reason, data)