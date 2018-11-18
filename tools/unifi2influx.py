import unifiapi
import json
import pprint

from influxdb import InfluxDBClient

import time

def main():
    output = []

    c = unifiapi.controller(endpoint='https://rocketfire.tech-cloud01.lan.sdok.no:8443', username='sdok', password='<REMOVED>', verify=False)
    s = c.sites['default']()
    pp = pprint.PrettyPrinter(indent=4)
    for ap in s.devices():
        fields = {}

        fields.update(ap['system-stats'])
        fields.update(ap['sys_stats'])
        fields.update({'state': ap['state']})
        fields.update({'num_sta': ap['num_sta']})

        #last_seen
        last_seen = int(time.time()) - int(ap['last_seen'])
        fields.update({'last_seen': last_seen})

        fields_cleaned = {}
        for key,field in fields.items():
            try:
                fields_cleaned.update({key:float(str(field).strip('"'))})
            except Exception as e:
                fields_cleaned.update({key:field})
        output.append(
        {
            "measurement": "unifi_ap_stat",
            "tags": {
                "name": ap['name'],
                "model": ap['model'],
                'mac': ap['mac'],
                'ip': ap['ip']
            },
            "fields": fields_cleaned
        }
        )


    client = InfluxDBClient('pluto.tech-cloud01.lan.sdok.no', 8086, 'root', 'root', 'gondul')
    client.write_points(output)
    print(output)

while True:
    main()
    time.sleep(30)