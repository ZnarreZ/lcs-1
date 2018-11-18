#!/usr/bin/python
import sys
import pymysql.cursors
import netaddr

# Connect to the database
connection = pymysql.connect(host='localhost',
                        user='kea',
                        password='<REMOVED>',
                        db='kea',
                        charset='utf8mb4',
                        cursorclass=pymysql.cursors.DictCursor)

with connection.cursor() as cursor:
        sql = "SELECT INET_NTOA(address) AS address, HEX(hwaddr) AS hwaddr, lease4.* FROM lease4"
        cursor.execute(sql)
        results = cursor.fetchall()
        for result in results:
                mac = ''
                if result['hwaddr']:
                        mac = ':'.join(format(s, '02x') for s in bytes.fromhex(result['hwaddr']))
                print(result['address'])
                #print(mac)
                #print(result['hostname'])
                #print(result['state'])
                #print('-----------------')

with connection.cursor() as cursor:
        sql = "SELECT address, HEX(hwaddr) AS hwaddr, lease6.* FROM lease6"
        cursor.execute(sql)
        results = cursor.fetchall()
        for result in results:
                mac = ''
                if result['hwaddr']:
                        mac = ':'.join(format(s, '02x') for s in bytes.fromhex(result['hwaddr']))
                print(result['address'])
                print(mac)
                print(result['hostname'])
                print(result['state'])
                print('-----------------')