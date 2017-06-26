git config --global user.name "lcgogo"
git config --global user.email "lcgogo123@163.com"

#################################################
# function ReplaceSpecialString
# $1 is the full path file name
# $2 is the keyword of the line whhich contains the string you want to replace
# $3 is the string you want to replace from
# $4 is the string you want to replace to
function ReplaceSpecialString(){
if [ ! -f $1 ];then
  echo $1 does not exist. Pls check Nuance is installed correctly. Exit now.
  exit 1
fi

lineNum=`cat -n $1 | grep "$2" | awk '{print $1}'`
echo  Replace $3 to $4 in file $1 line $lineNum.

sedString="$lineNum""s/""$3""/""$4""/g"

sed -i "$sedString" $1
}

url=`grep "lcgogo@github.com" .git/config`
if [ "$url" ];then
  echo This git folder is configed for lcgogo.
  exit
  else
    ReplaceSpecialString ".git/config" "url" "github.com" "lcgogo@github.com" 
fi
