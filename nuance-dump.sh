# Modified from https://sqbu-github.cisco.com/gist/andrthen/509dd8c1f0bd242193f8
# Lewis Li removes search nuance license in nuance license management nodes. 

#!/usr/bin/env bash

die() {
  echo 'nuance-dump failed:' $1
  return 1
}

if [ -z "$1" ]
then
  echo 'Usage: nuance-dump HOSTNAME'
  exit 1
fi

TARGET_HOST=$1 
NAME=`date +"nuance-dump-$TARGET_HOST-%Y%m%d.%H%M%S"`

echo "*** Creating dump $NAME..."
mkdir "$NAME"

cat <<-EOS > $NAME/README.txt
  This dump was generated for the Support Team at Nuance.
  
  Organization: Tropo / Cisco
  Order Number: 349702
  License Access Control: 16977-10982912
  Licensing scheme: per minute

  TOPOLOGY AS OF 2016-04-11
  -------------------------
  
  WDC Datacenter:

  We have 36 speech servers organized into the following layout:

    - n-asr1 thru n-asr9    : recognizers (primary)
    - n-asr10 thru n-asr18  : recognizers (secondary)
    - n-tts1 thru n-tts9    : vocalizers  (primary)
    - n-tts10 thru n-tts18  : vocalizers  (secondary)

  Each speech server is configured with a profile so that it may act in "recognizer-only" mode or "vocalizer-only" mode.
  In addition to these servers, there are 2 management stations:

    - nuance-mgr1           : management station
    - nuance-mgr2           : management station

  The speech servers and the management stations DO NOT run their on licmgr process. Instead, they are configured to
  hit up our 2 license servers on port 27000:

    - nuance-mgr3 / n-lic3  : license server
    - nuance-mgr4 / n-lic4  : license server

EOS

echo '*** Getting license data...'
mkdir $NAME/license
scp $TARGET_HOST:/var/local/Nuance/system/diagnosticLogs/lm.log \
  $NAME/license/$TARGET_HOST-lm.log 2>/dev/null;

nuanceLicense=`ps -ef | grep "components\/lmgrd" | awk {'print $10'}`

if [ "$nuanceLicense" ];then
  echo The Nuance license file is $nuanceLicense.
scp $TARGET_HOST:$nuanceLicense \
  $NAME/license/$TARGET_HOST-license.lic 2>/dev/null;
  else
    echo The Nuance License Manager is NOT running. Exit now. Pls fix it and rerun this script.
fi

#scp $TARGET_HOST:/usr/local/Nuance/license_manager/license/license.lic \
#  $NAME/license/$TARGET_HOST-license.lic 2>/dev/null;

#for lmhost in nuance-mgr{3,4}; do
#  scp $lmhost.prod.wdc.sl.tropo.com:/var/local/Nuance/system/diagnosticLogs/lm.log \
#    $NAME/license/$lmhost-lm.log 2>/dev/null;
#  scp $lmhost.prod.wdc.sl.tropo.com:/usr/local/Nuance/license_manager/license/license.lic \
#    $NAME/license/$lmhost-license.lic 2>/dev/null;
#done

if [[ "$TARGET_HOST" =~ asr ]]
then
  echo "*** Getting recognizer files..."
  scp "$TARGET_HOST:/usr/local/Nuance/Recognizer/config/{Baseline.xml,SpeechWorks.cfg}" $NAME/
  scp "$TARGET_HOST:/var/local/Nuance/system/config/User{-nrs01.xml,_nss01.txt}" $NAME/
elif [[ "$TARGET_HOST" =~ tts ]] 
then
  echo "*** Getting vocalizer files..."
  scp "$TARGET_HOST:/usr/local/Nuance/Vocalizer_for_Enterprise/config/baseline.xml" $NAME/
  scp "$TARGET_HOST:/var/local/Nuance/system/config/User{-nvs01.xml,_nss01.txt}" $NAME/
fi

echo "*** Getting NSS config..."
mkdir $NAME/nss-config
scp "$TARGET_HOST:/usr/local/Nuance/Speech_Server/server/config/*" $NAME/nss-config/

echo "*** Getting Nuance version info..."
ssh $TARGET_HOST "nuance-version -p -s > /tmp/$NAME-nuance-version.txt"
scp "$TARGET_HOST:/tmp/$NAME-nuance-version.txt" $NAME/nuance-version.txt
ssh $TARGET_HOST "rm -f /tmp/$NAME-nuance-version.txt"

echo "*** Getting diagnosticLogs..."
mkdir $NAME/diagnosticLogs
scp "$TARGET_HOST:/var/local/Nuance/system/diagnosticLogs/*" $NAME/diagnosticLogs

tar cfj $NAME.tar.bz2 $NAME && rm -Rf $NAME
