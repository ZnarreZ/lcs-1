import requests
import json
from influxdb import InfluxDBClient
import time

def dnsdist(name, host):
    output = []
    headers = {'X-API-Key': '<REMOVED>'}
    r = requests.get('http://{}:8083/jsonstat?command=stats'.format(host), headers=headers)
    fields = json.loads(r.text)
    fields_cleaned = {}
    for key,field in fields.items():
        try:
            fields_cleaned.update({key:float(str(field).strip('"'))})
        except Exception as e:
            fields_cleaned.update({key:field})

    output.append(
    {
        "measurement": "dnsdist",
        "tags": {
            "name": name,
            "host": host
        },
        "fields": fields_cleaned
    }
    )

    client = InfluxDBClient('pluto.tech-cloud01.lan.sdok.no', 8086, 'root', 'root', 'gondul')
    client.write_points(output)
    print(output)

def recursor(name, host, id = 'localhost'):
    output = []
    headers = {'X-API-Key': '<REMOVED>'}
    r = requests.get('http://{0}:8082/api/v1/servers/{1}/statistics'.format(host, id), headers=headers)
    fields = json.loads(r.text)
    fields_cleaned = {}
    for item in fields:
        key = item['name']
        field = item['value']
        try:
            fields_cleaned.update({key:float(str(field).strip('"'))})
        except Exception as e:
            fields_cleaned.update({key:field})

    output.append(
    {
        "measurement": "pdns_recursor",
        "tags": {
            "name": name,
            "host": host
        },
        "fields": fields_cleaned
    }
    )

    client = InfluxDBClient('pluto.tech-cloud01.lan.sdok.no', 8086, 'root', 'root', 'gondul')
    client.write_points(output)
    print(output)

while True:
    dnsdist('terra','213.184.213.226')
    dnsdist('luna','213.184.213.227')
    recursor('terra','213.184.213.226')
    recursor('luna','213.184.213.227')
    time.sleep(5)