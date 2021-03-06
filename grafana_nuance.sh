#!/bin/sh

thisfile=$0
thisfolder=${thisfile%/*}

# Part 1. Set up collectd
service ntpd stop
ntpdate 10.75.187.203
yum -y install libcurl libcurl-devel rrdtool rrdtool-devel rrdtool-prel libgcrypt-devel gcc make automake gcc-c++ kernel-devel perl-devel perl-CPAN
wget http://collectd.org/files/collectd-5.5.0.tar.gz
tar -zxvf collectd-5.5.0.tar.gz
cd collectd-5.5.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --mandir=/usr/share/man --enable-all-plugins
make
make install

scp root@10.75.187.197:/etc/collectd.conf /etc/

# Start the colectd  daemon
# Copy the default init.d script
 
cp /root/autoNuance/collectd-5.5.0/contrib/redhat/init.d-collectd /etc/init.d/collectd
 
# Set the correct permissions
 
chmod +x /etc/init.d/collectd

# Add the service to start when host restarted
chkconfig --add collectd
chkconfig collectd on
 
# Start the deamon
 
service collectd start


# Part 2. Set up Metricbeat for process cpu usage
curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-5.4.3-x86_64.rpm
sudo rpm -vi metricbeat-5.4.3-x86_64.rpm

mkdir /etc/metricbeat/
scp root@10.75.187.197:/etc/metricbeat/metricbeat.yml /etc/metricbeat/
sed -i "s/tropo-197.cisco.com/`hostname`/g" /etc/metricbeat/metricbeat.yml

sudo /etc/init.d/metricbeat start
sudo chkconfig --add metricbeat
sudo chkconfig metricbeat on

echo Done.
