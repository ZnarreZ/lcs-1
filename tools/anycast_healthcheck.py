import dns.resolver
from subprocess import call

# TODO Make it check dnsdist status and not just google.com

# Current status
f = open("status.tmp", "r")
old_status = f.read()

print("Status was {0}".format(old_status))

try:
    resolver = dns.resolver.Resolver(configure=False)
    resolver.timeout = 1
    resolver.lifetime = 1
    resolver.nameservers = ['213.184.213.10']
    answer = resolver.query('google.com')
    for item in answer:
        print(item)
    if old_status != 'UP':
        call(['/usr/bin/vtysh', '-c', 'configure terminal', '-c', 'router ospf', '-c' ,'network 213.184.213.10/32 area 0.0.0.0', '-E'])
        call(['/usr/bin/vtysh', '-c', 'configure terminal', '-c', 'router ospf6', '-c' ,'interface lo area 0.0.0.0', '-E'])
    file = open("status.tmp","w")
    file.write("UP")
    file.close()
except Exception as e:
    print(e)
    if old_status != 'DOWN':
        call(['/usr/bin/vtysh', '-c', 'configure terminal', '-c', 'router ospf', '-c' ,'no network 213.184.213.10/32 area 0.0.0.0', '-E'])
        call(['/usr/bin/vtysh', '-c', 'configure terminal', '-c', 'router ospf6', '-c' ,'no interface lo area 0.0.0.0', '-E'])
    file = open("status.tmp","w")
    file.write("DOWN")
    file.close()