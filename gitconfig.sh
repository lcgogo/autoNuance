# This script is used to config your github account in current folder

yourname="lcgogo"
youremail="lcgogo123@163.com"
yourgithub="$yourname"@github.com

git config --global user.name $yourname
git config --global user.email $youremail

echo "unset SSH_ASKPASS" >> ~/.bashrc
source ~/.bashrc

#################################################
# function ReplaceSpecialString
# $1 is the full path file name
# $2 is the keyword of the line which contains the string you want to replace
# $3 is the string you want to replace from
# $4 is the string you want to replace to
function ReplaceSpecialString(){
if [ ! -f $1 ];then
  echo $1 does not exist. Exit now.
  exit 1
fi

lineNum=`cat -n $1 | grep "$2" | awk '{print $1}'`
echo  Replace $3 to $4 in file $1 line $lineNum.

sedString="$lineNum""s/""$3""/""$4""/g"

sed -i "$sedString" $1
}

# Add $yourname to the url in ./.git/config

url=`grep "$yourgithub" ./.git/config`
if [ "$url" ];then
  echo This git folder is configured for $yourname.
  else
    ReplaceSpecialString "./.git/config" "url" "github.com" "$yourgithub" 
fi

echo If you met gnome-ssh-askpass issue when \"git push\", exit and relogin this server.

exit
