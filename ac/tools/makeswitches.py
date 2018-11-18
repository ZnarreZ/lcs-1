import ipaddress
import requests
import json

base_network_v4 = ipaddress.ip_network('213.184.214.0/23')
subnet_size_v4 = 27

base_network_v6 = ipaddress.ip_network('2a0b:5102:0:200::/59')
subnet_size_v6 = 64

base_subnets_v4 = list(base_network_v4.subnets(new_prefix=subnet_size_v4))
base_subnets_v6 = list(base_network_v6.subnets(new_prefix=subnet_size_v6))

start_vlan_id = 200

distro = [
    {"name": "distro1", "port_name": "ge-0/0/{0}", "port_counter": 0},
    {"name": "distro2", "port_name": "ge-0/0/{0}", "port_counter": 0}
]

rows = [
    {"row": 1, "switches": 2, "distro": 1},
    {"row": 2, "switches": 2, "distro": 1},
    {"row": 3, "switches": 2, "distro": 1},
    {"row": 4, "switches": 2, "distro": 0},
    {"row": 5, "switches": 2, "distro": 0},
    {"row": 6, "switches": 2, "distro": 0}
]

net_count = 0
row_count = 0

for row in rows:
    sw_count = 0
    row_count += 1
    for sw in range(row['switches']):
        sw_count += 1
        distro_name = distro[row['distro']]['name']
        port = distro[row['distro']]["port_name"].format(distro[row['distro']]["port_counter"])
        distro[row['distro']]["port_counter"] += 1
        subnet_v4 = base_subnets_v4[net_count]
        subnet_v6 = base_subnets_v6[net_count]
        name = "E{0}-{1}".format(row_count,sw_count)
        #
        gw4 = ipaddress.IPv4Network(subnet_v4)[1].exploded
        gw6 = ipaddress.IPv6Network(subnet_v6)[1].exploded
        switch4 = ipaddress.IPv4Network(subnet_v4)[2].exploded
        switch6 = ipaddress.IPv6Network(subnet_v6)[2].exploded

        data = json.dumps([{'sysname': name, 'distro_name': distro_name, 'distro_phy_port': port, 'traffic_vlan': name, 'mgmt_vlan': name, 'mgmt_v4_addr': switch4, 'mgmt_v6_addr': switch6, 'community':'<removed>' , 'tags': '["dlink","simplesnmp", "new"]'}])
        r = requests.post("http://gondul.lan.sdok.no/api/write/switch-update", data=data, headers={'content-type': 'application/json'})
        print(r.status_code, r.reason, data)

        data = json.dumps([{'name': name, 'subnet4': str(subnet_v4), 'subnet6': str(subnet_v6), 'gw4': gw4, 'gw6': gw6, 'routing_point': distro_name, 'vlan': start_vlan_id, 'tags': '["dhcp", "clients"]'}])
        r = requests.post("http://gondul.lan.sdok.no/api/write/network-update", data=data, headers={'content-type': 'application/json'})
        print(r.status_code, r.reason, data)


        print("{0} - {1}:{2}, {3} - {4} - {5}".format(name, distro_name, port, subnet_v4, subnet_v6, start_vlan_id))
        #
        net_count += 1
        start_vlan_id += 1