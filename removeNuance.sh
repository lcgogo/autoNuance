#!/bin/bash

# The script is used to remove Nuance TOTALLY!
# ONLY USED FOR TEST.

rpmResult=`rpm -qa | grep -E "nuance|Nuance|mstation|tomcat|NRec|NSS|NVE|mysql|MySQL" | sort`
if [ "$rpmResult" != "" ]; then
  echo There are some Nuance related rpms exists.
  echo $rpmResult
  echo Please run "setup.sh -R" to remove Nuance at first. Then run this script.
  exit
fi

rm -f /root/.mysql_secret
rm -rf /var/lib/mysql /usr/lib64/mysql
rm -rf /var/local/Nuance /usr/local/Nuance
