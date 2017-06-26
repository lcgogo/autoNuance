#!/bin/sh
#
# Background:
# This script is used for automatic change Nuance Managerment Station tomcat working web port from 8080 to 8081 or what you want.
# Only used for deploy Nuance and Tropo runtime in one server because runtime vcs uses 8080 defaultly.
# The script covers followed 2 sections in Nuance+Speech+Suite+10.5+Installation+with+Tropo+Runtime+progress.doc
# Change the NMS port from 8080 to 8081 & Config and Startup Nuance Services by Command Line Interface (CLI)
# https://voxeolabs.atlassian.net/wiki/display/CS/Nuance+Speech+Suite+10.5+Installation+with+Tropo+Runtime+progress
#
# Author: Lewis Li
# Email: chali2@cisco.com
# Phone: +86 13911983435
# 2016.Nov.28th Ver 1.0  New script.
# 2016.Nov.29th Ver 1.1  Add a step to check tropo_services running or not.
# 2016.Dec.2rd  Ver 1.2  Add a step to read tts_port from user input and set the tts_port for NVE.
# 2016.Dec.9th  Ver 1.2.1 Add more comments and printout.
# 2016.Dec.13th Ver 1.3 Change the check cmd Result of Nuance configuration. Add Sys_dt function.
# 2017.Apr.28th Ver 1.4 Add function ResultPrint.
# 2017.May.16th Ver 2.0 Change port 8081 to a variable as Ver 2.0
# 2017.May.24th Ver 2.1 Add a check for tropoIsInstalled, rewrite the logic hwo to do after `which tropo_services`
# 2017.May.25th Ver 2.2 Add a printout : echo [`Sys_dt`] Tropo is installed. Need stop it before Nuance deploy.
# 2017.May.26th Ver 2.3 Add a check for super user running.
# 2017.May.26th Ver 2.4 Add a memory check, must larger than 1.5G. And replan the exit error code.
# 2017.May.31th Ver 2.5 Add a voice package rpm check.
# 2017.Jun.6th  Ver 2.6 Add a step to check hostname, it can't be localhost.
# 2017.Jun.9th  Ver 2.7 Add a Nuance license check and decide the testflag by the result of checking.
# 2017.Jun.12th Ver 2.8 Change some log printout more readable.
# Plan:
# 1. add a remove t_hosts  step from mysql if assign-role.sh fail with duplicated host name

# Exit error code
# 0 Run this script completed.
# 1 Exit without any modify to file or system.
# 2 File changes failed.
# 3 Command failed.


#############
# Preparing #
#############

###############################################
# Global variables
thishost=`hostname -f`
nuancePort=8081

echo "##############################################"
echo "# The script is used to deploy Nuance 10.5.3 with Tropo runtime."
echo "# The Nuance Speech Suite setup.sh must be completed and Nuance voices are installed."
echo "# If any stop with \"Exit now\", check the Nuance+Speech+Suite+10.5+Installation+with+Tropo+Runtime+progress.doc for more details."
echo "# https://voxeolabs.atlassian.net/wiki/display/CS/Nuance+Speech+Suite+10.5+Installation+with+Tropo+Runtime+progress"
echo "# The script has 2 parts:"
echo "# 1. Change the Nuance Management Station tomcat working web port from 8080 to $nuancePort"
echo "# 2. Config and Startup Nuance Services by Command Line Interface (CLI)"
echo "##############################################"

###############################################
# function Sys_dt
function Sys_dt(){
echo `date +%Y-%m-%d-%H:%M:%S`
}
###############################################

# Are you a super user?
if [ "`id -u`" != "0" ]; then
  echo [`Sys_dt`] "You must be a superuser to run this script. Exit now. Pls fix it and rerun this script."
  exit 1
  else
    echo [`Sys_dt`] "Running as superuser."
fi

# Memory must be larger than 1.5G, otherwise NMS can't stop/start
if [ `free -m | grep Mem | awk '{print $2}'` -lt 1500  ]; then
  echo [`Sys_dt`] "The NMS can't stop/start at this host because the memory is less than 1.5G." 
  echo [`Sys_dt`] "Pls increase memory larger than 1.5GB. Exit now. Pls fix it and rerun this script."
  exit 1
fi

# Check whether Nuance Speech Suite is installed
echo [`Sys_dt`] Check the Nuance Speech Suite is installed.
if [ ! -e /etc/init.d/nuance-wd ];then
  echo Nuance watch daemeon file is not existed. The Nuance is not installed. Exit now. Pls fix it and rerun this script.
  exit 1
  else
    echo "/etc/init.d/nuance-wd exists. Nuance Speech Suite is installed. Continue."
fi

# NRE & NVE Voice packages must be installed. Otherwise the config will meet Fatal Error.
if [ `rpm -qa | grep -i nve | wc -l` -lt 2 ];then
  echo [`Sys_dt`] The NVE voice package is not installed. Pls install at least one at first. Exit now. Pls fix it and rerun this script.
  exit 1
fi
if [ `rpm -qa | grep -i nre | wc -l` -lt 2 ];then
  echo [`Sys_dt`] The NRE voice package is not installed. Pls install at least one at first. Exit now. Pls fix it and rerun this script.
  exit 1
fi

# Check the "hostname -f". Should not be localhost.
if [ "$thishost" = "localhost" ];then
  echo [`Sys_dt`] The \"hostname -f\" is localhost. Pls change it in /etc/hosts. Exit now. Pls fix it and rerun this script.
  exit 1
fi

# Check the Nuance License Manager installed.
if [ -e /etc/init.d/nuance-licmgr ];then
  echo [`Sys_dt`] The Nuance License Manager is installed in this host.
  else
    echo [`Sys_dt`] The Nuance License Manager is NOT installed in this host. Exit now. Pls fix it and rerun this script.
    exit 1
fi

# Check the Nuance license file.
nuanceLicense=`ps -ef | grep "components\/lmgrd" | awk {'print $10'}`
if [ "$nuanceLicense" ];then
  echo [`Sys_dt`] The Nuance license file is $nuanceLicense.
  else
    echo [`Sys_dt`] The Nuance License Manager is NOT running. Exit now. Pls fix it and rerun this script.
    exit 1
fi

# Is this a test license file or not.
hostid_in_licensefile=`grep "SERVER this_host" $nuanceLicense | sort -u | awk '{print $3}'`
if [ "$hostid_in_licensefile" = "ANY" ];then
  echo [`Sys_dt`] This is a test Nuance license running. The test license will be restricted to 4 ports.
  testflag=yes
  else
    testflag=no
    echo [`Sys_dt`] This is NOT a test Nuance license running. Please input the ports number.
    echo -en "Please input the NVE TTS port number: "
    read tts_port
    echo -en "Please input the NRS ASR port number: "
    read asr_port
fi
echo [`Sys_dt`] The testflag is $testflag.

###############################################
# Is this a test Nuance host?
#echo "Test Nuance license will be restricted to 4 ports."
#echo -en "Is this a test Nuance host [Y/N]: "
#read choice
#
#case $choice in
#  Y|y) testflag=yes
#     echo [`Sys_dt`] This is a test Nuance host. The test license will be restricted to 4 ports.
#  ;;
#  N|n) testflag=no
#
#     echo [`Sys_dt`] This is not a test Nuance host. Input the TTS port number in license.lic
#     echo -en "Please input the NVE TTS port number: "
#     read tts_port
#       if [[ $tts_port -gt 100 ]];then
#         echo The NVE TTS port is larger than 100. Need install Nuance in a seperated host. Exit now.
#         exit 1
#       fi
#
#     echo [`Sys_dt`] This is not a test Nuance host. Input the ASR port number in license.lic
#     echo -en "Please input the NRS ASR port number: "
#     read asr_port
#       if [[ $asr_port -gt 100 ]];then
#         echo The NRS ASR port is larger than 100. Need install Nuance in a seperated host. Exit now.
#         exit 1
#       fi
#
#  ;;
#  *) echo [`Sys_dt`] Invalid input. Please input Y or N. Your input is $choice. Exit now.
#    exit 1
#  ;;
#esac

#echo [`Sys_dt`] The testflag is $testflag.

################################################
# function ServiceStop
function ServiceStop(){
serviceName=$1 # the service name  which under folder /etc/init.d
serviceKeyword=$2 # the service process keyword of "ps -ef" result. use it to check whether it's stopped or not

service $serviceName stop

serviceStopResult=`ps -ef | grep -w $serviceKeyword | grep -v grep | wc -l` # the value should be 0 if the service is stopped.
# echo serviceStopResult = $serviceStopResult

if [ $serviceStopResult -ne 0 ];then
  echo [`Sys_dt`] $serviceName is not stopped. Manual check by "ps -ef | grep -w $serviceKeyword" and stop it by kill.
fi
}

#################################################
# function ReplaceSpecialString
# $1 is the full path file name
# $2 is the keyword of the line which contains the string you want to replace
# $3 is the string you want to replace from
# $4 is the string you want to replace to
function ReplaceSpecialString(){
if [ ! -f $1 ];then
  echo [`Sys_dt`] $1 does not exist. Pls check Nuance is installed correctly. Exit now. Pls fix it and rerun this script.
  exit 1
fi
#backup
cp $1 $1.`Sys_dt`

lineNum=`cat -n $1 | grep "$2" | awk '{print $1}'`
echo [`Sys_dt`] Replace $3 to $4 in file $1 line $lineNum.

sedString="$lineNum""s/""$3""/""$4""/g"

sed -i "$sedString" $1
}

################################################
# fucntion ResultPrint
# $1 is the Nuance module name, like NVE, NRE, NSS
function ResultPrint(){
if [ "$cmdResultTitle" = "Successful" ];then
  echo [`Sys_dt`] The service-configuration.sh of $1 result is $cmdResultTitle.
  else
    echo [`Sys_dt`] The service-configuration.sh of $1 result is $cmdResultTitle but not Successful.
    echo [`Sys_dt`] The command is not successful executed. Check the printout. Exit now.
    echo [`Sys_dt`] The command printout is below:
    echo [`Sys_dt`] $cmdResult
    exit 3
fi
}

########
# MAIN #
########
echo "##############################################################"
echo "# 1. Change the NMS port from 8080 to $nuancePort"
echo "##############################################################"

# Stop Tropo services if any
echo [`Sys_dt`] Check the Tropo services are stopped.
which tropo_services

case $? in
  0) tropoIsInstalled=yes
     echo [`Sys_dt`] Tropo is installed. Need stop it before Nuance deploy.
     if [ `tropo_services status | grep running | wc -l` -ne 0 ];then
       echo [`Sys_dt`] Tropo is running. Stop it now.
       tropo_services stop
       sleep 30s
       tropoIsStop=yes
     else
       echo [`Sys_dt`] Tropo is not running. Continue deploy Nuance.
       tropoIsStop=yes
     fi
  ;;
  1) tropoIsInstalled=no
     echo [`Sys_dt`] Tropo is not installed. Continue deploy Nuance.
  ;;
  *) echo [`Sys_dt`] Unknown result of \"which tropo_services\". Exit now. Pls fix it and rerun this script.
     exit 1
  ;;
esac

# Stop Nuance service
echo [`Sys_dt`] Stop services: initScriptmserver.sh initScriptmserverdc.sh initScriptmserversa.sh "&" nuance-wd.
ServiceStop "initScriptmserver.sh" "mstation\mserver"
ServiceStop "initScriptmserverdc.sh" "mstation\mserverdc"
ServiceStop "initScriptmserversa.sh" "mstation\mserversa"
ServiceStop "nuance-wd" "watcher-daemon"

# Replace 8080 to $nuancePort if nuancePort is not 8080
if [ $nuancePort -ne 8080 ];then
ReplaceSpecialString /usr/local/Nuance/OAM/data/oam/mserver_hosts.txt "localhost" "8080" "$nuancePort"
ReplaceSpecialString /usr/local/Nuance/Management_Station/mstation/mserver/conf/server.xml "Connector port"  "8080" "$nuancePort"
ReplaceSpecialString /usr/local/Nuance/Management_Station/mstation/mserver/webapps/mserver/config/mserver_cfg.properties "mstationAddr"  "8080" "$nuancePort"
ReplaceSpecialString /usr/local/Nuance/Management_Station/mstation/mserverdc/webapps/mserver/config/mserver_cfg.properties "mstationAddr"  "8080" "$nuancePort"
ReplaceSpecialString /usr/local/Nuance/Management_Station/mstation/mserversa/webapps/mserver/config/mserver_cfg.properties "mstationAddr"  "8080" "$nuancePort"
fi


# Start Nuance service
service initScriptmserver.sh start
sleep 5s
service initScriptmserverdc.sh start
sleep 5s
service initScriptmserversa.sh start
sleep 5s
service nuance-wd start
sleep 45s

# Check the webserver status
curl "http://localhost:$nuancePort/mserver/jsp/main-frame.jsp"
if [ $? -eq 7 ];then
  echo [`Sys_dt`] The Nuance tomcat is not startup. Manual check. Exit now.
  exit 2
fi
echo [`Sys_dt`] Check the curl result.

# Check the nuance-wd status
echo [`Sys_dt`] Check the nuance-wd status.
service nuance-wd status
if [ $? -ne 0 ];then
  echo [`Sys_dt`] The nuance-wd service is not running normal. Manual check. Exit now.
  exit 3
fi

# Change FTS starttype from manual to automatic
ReplaceSpecialString /usr/local/Nuance/Management_Station/mstation/mserver/webapps/mserver/config/roles/1NSS_1NRS_1NVS_SC.xml "\"File Transfer\"" "manual" "automatic"

echo "#############################################################"
echo "# 2. Config and Startup Nuance Services by Command Line Interface (CLI)"
echo "##############################################################"
# Export $MSTATION_HOME
export MSTATION_HOME=/usr/local/Nuance/Management_Station/mstation

# Add Nuance server config
echo [`Sys_dt`] Assign this host as a Nuance server. Expected result is Successful.
cd /usr/local/Nuance/Management_Station/mstation/mserver/webapps/mserver/scripts
cmdResult=`./assign-role.sh -hostname $thishost -password changeit -port $nuancePort -rolefilename 1NSS_1NRS_1NVS_SC.xml -servername $thishost -username Administrator`
cmdResultTitle=`echo $cmdResult | head -n 1`
ResultPrint "NMS"

# NVE test license setting
if [ "$testflag" = "yes"  ];then
  echo [`Sys_dt`] This is a test host, set the NVE TTS port to 4.
cat > /var/local/Nuance/system/config/nvs_update_config.txt <<EOF
tts_license_ports=4
tts_license_ports_overdraft_thresh=4
EOF
  else
    echo [`Sys_dt`] The NVE TTS port is $tts_port, put it in /var/local/Nuance/system/config/nvs_update_config.txt
cat > /var/local/Nuance/system/config/nvs_update_config.txt <<EOF
tts_license_ports=$tts_port
tts_license_ports_overdraft_thresh=$tts_port
EOF
fi

# NVE SSML config
ReplaceSpecialString /usr/local/Nuance/Vocalizer_for_Enterprise/config/baseline.xml "ssml_validation" "strict" "none"

# Add NVE config
echo [`Sys_dt`] Add Nuance Voice Engine config. Expected result is Successful.
cd /usr/local/Nuance/Management_Station/mstation/mserver/webapps/mserver/scripts
cmdResult=`./service-configuration.sh -configuration /var/local/Nuance/system/config/nvs_update_config.txt -operation Update -hostname $thishost -password changeit -port $nuancePort -restart -servername $thishost -servicename "Nuance Vocalizer Service" -username Administrator`
cmdResultTitle=`echo $cmdResult | head -n 1`
ResultPrint "NVE"

# NRS test license setting
if [ "$testflag" = "yes"  ];then
  echo [`Sys_dt`] This is a test host, set the NRS license to 4.
cat > /var/local/Nuance/system/config/nrs_update_config.txt <<EOF
swirec_license_ports=4
swiep_license_ports=4
EOF
  else
    echo [`Sys_dt`] The NRS ASR port is $asr_port, put it in /var/local/Nuance/system/config/nrs_update_config.txt
cat > /var/local/Nuance/system/config/nrs_update_config.txt <<EOF
swirec_license_ports=$asr_port
swiep_license_ports=$asr_port
EOF
fi

# Add NRS config
echo [`Sys_dt`] Add Nuance Recognition Service config. Expected result is Successful.
cd /usr/local/Nuance/Management_Station/mstation/mserver/webapps/mserver/scripts
cmdResult=`./service-configuration.sh -configuration /var/local/Nuance/system/config/nrs_update_config.txt -operation Update -hostname $thishost -password changeit -port $nuancePort -restart -servername $thishost -servicename "Nuance Recognition Service" -username Administrator`
cmdResultTitle=`echo $cmdResult | head -n 1`
ResultPrint "NRS"

# NSS SIP port setting
cat > /var/local/Nuance/system/config/nss_update_config.txt <<EOF
server.mrcp2.sip.transport.tcp.port=15060
server.mrcp2.sip.transport.udp.port=15060
server.mrcp2.sip.transport.tls.port=15061
EOF

# Restart nuance-wd service
ServiceStop "nuance-wd" "watcher-daemon"
service nuance-wd start
sleep 30s
# Check the nuance-wd status
echo [`Sys_dt`] Check the nuance-wd status
service nuance-wd status
if [ $? -ne 0 ];then
  echo [`Sys_dt`] The nuance-wd service is not running normal. Manual check. Exit now.
  exit 3
fi

# Add NSS config
echo [`Sys_dt`] Add Nuance Speech Server config. Expected result is Successful.
cd /usr/local/Nuance/Management_Station/mstation/mserver/webapps/mserver/scripts
cmdResult=`./service-configuration.sh -configuration /var/local/Nuance/system/config/nss_update_config.txt -operation Update -hostname $thishost -password changeit -port $nuancePort -restart -servername $thishost -servicename "Nuance Speech Server" -username Administrator`
cmdResultTitle=`echo $cmdResult | head -n 1`
ResultPrint "NSS"

# Restart nuance-wd service
ServiceStop "nuance-wd" "watcher-daemon"
service nuance-wd start
sleep 30s
# Check the nuance-wd status
echo [`Sys_dt`] Check the nuance-wd status.
service nuance-wd status
if [ $? -ne 0 ];then
  echo [`Sys_dt`] The nuance-wd service is not running normal. Manual check. Exit now.
  exit 3
fi

# Start Tropo services or not
if [[ $tropoIsInstalled = yes && $tropoIsStop = yes && $nuancePort -ne 8080 ]];then
  echo [`Sys_dt`] Start tropo_services now. Please check the result.
  tropo_services start
fi

##############################################################
# Complete, print the result as green
echo -e [`Sys_dt`] "\033[32;49;1m The Nuance Speech Suite is configured and deployed in this host. \033[39;49;0m"

exit 0
