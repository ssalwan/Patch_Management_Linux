###################################################
#!/bin/bash
#
#
#
#
#Patch Management script - Includes healtchecks
##################################################


###Load the variables!
export a=`date | awk {'print $3 " " $2 " " $6'}`
export b=`date | awk {'print $3 "_" $2 "_" $6'}`
export patch_file=/tmp/Patches_$b
export content_to_mail=/tmp/Content_to_mail_$b
#export prechecks="Location of prechecks file"
#export postchecks="Location of postchecks file"
export prechecks=/tmp/prechecks_$b.txt
export postchecks=/tmp/postchecks_$b.txt
export diff_checks=/tmp/diff-checks_$b.txt
export EMAIL=shubham.salwan@iongroup.com


###Touch files
touch $prechecks
touch $prechecks

#Reset previous variables
unset tecreset os internalip externalip nameserver

###Prechecks
check ()
{

# Define Variable tecreset
tecreset=$(tput sgr0)

# Check if connected to Internet or not
ping -c 1 google.com &> /dev/null && echo -e '\E[32m'"Internet: $tecreset Connected" || echo -e '\E[32m'"Internet: $tecreset Disconnected"

# Check OS Type
os=$(uname -o)
echo -e '\E[32m'"Operating System Type :" $tecreset $os

# Check OS Release Version and Name
cat /etc/os-release | grep 'NAME\|VERSION' | grep -v 'VERSION_ID' | grep -v 'PRETTY_NAME' > /tmp/osrelease
echo -n -e '\E[32m'"OS Name :" $tecreset  && cat /tmp/osrelease | grep -v "VERSION" | cut -f2 -d\"
echo -n -e '\E[32m'"OS Version :" $tecreset `cat /etc/os-release | grep -w VERSION | cut -f2 -d=`
echo " "
# Check Architecture
architecture=$(uname -m)
echo -e '\E[32m'"Architecture :" $tecreset $architecture

# Check hostname
echo -e '\E[32m'"Hostname :" $tecreset $HOSTNAME

# Check Internal IP
internalip=$(hostname -I)
echo -e '\E[32m'"Internal IP :" $tecreset $internalip

# Check External IP
externalip=$(curl -s ipecho.net/plain;echo)
echo -e '\E[32m'"External IP : $tecreset "$externalip

# Check DNS
nameservers=$(cat /etc/resolv.conf | sed '1 d' | awk '{print $2}')
echo -e '\E[32m'"Name Servers :" $tecreset $nameservers

#Check total CPU processors
echo -e '\E[32m'"CPU processors :" $tecreset `grep -c ^processor /proc/cpuinfo`

# Check total RAM and SWAP
echo -e '\E[32m'"Physical Memory :" $tecreset `cat /proc/meminfo  | grep MemTotal | awk {'print $2 " " $3'}`
echo -e '\E[32m'"Swap Memory :" $tecreset `cat /proc/meminfo  | grep SwapTotal | awk {'print $2 " " $3'}`


# Check Disk Usages
df -hP > /tmp/diskusage
echo -e '\E[32m'"Disk Usages :" $tecreset
cat /tmp/diskusage

# Number of mount points
echo -e '\E[32m'"Number of mount points :" $tecreset  $(df -hP |grep -v Filesystem | wc -l)

###List of the running services in RHEL 7+
echo -e '\E[32m'"List of all the running services :" $tecreset
echo " ****************************************************************************************************************************************************************************************************************** "
systemctl | grep running | grep -vE "session-1.scope|session-c1.scope"
echo " ****************************************************************************************************************************************************************************************************************** "

# Remove Temporary Files
rm /tmp/osrelease /tmp/diskusage
shift $(($OPTIND -1))

}


###Capture if the patches got installed today
Patch_Capture()
{

###Touch files
touch $patch_file

###Load the num of patches variable
export num_patches=$(cat $patch_file | wc -l)


###Fetch the patches in $patch_file that got installed on the current date
rpm -qa --last | while read i
do
if [[ `echo $i | awk {'print $3 " "$4 " " $5'}` = "$a" ]]
then
  echo $i | awk {'print $1'} >> $patch_file
fi
done

if [[ ! -s $patch_file ]]
then
 echo "No patches installed today" >> $patch_file
fi
}


###Monitor if the server got rebooted and  patches got installed on the current date
Patch_Mon()
{

###Touch files
touch $content_to_mail

###Difference in prechecks and postchecks?
if [[ -f $prechecks && -f $postchecks ]]
then
    diff $prechecks $postchecks > $diff_checks
		if [[ ! -s $diff_checks ]]
           then
           export ans="Yes"
        else
		   export ans="No"
        fi
fi

###Find out if server got rebooted on the current date?
if [[ `who -b | awk '{print $3}'` = $(date +%F) ]]
then
  echo "Server rebooted today!! " >> $content_to_mail
  if [[ $ans = "Yes" ]]
  then
  echo "Difference in checks found : $ans " >> $content_to_mail
  echo $(sdiff $prechecks $postchecks) >> $content_to_mail
  echo ""
  fi
fi

###Display if the patches got installed on the current date.
if [[ `cat $patch_file` = "No patches installed today" ]]
then
  echo "No patches installed today" >> $content_to_mail
else
  echo ".. " >> $content_to_mail
  echo "We see $num_patches patches have been installed today " >> $content_to_mail
  echo ".. " >> $content_to_mail
  echo ".. " >> $content_to_mail
  cat $patch_file >> $content_to_mail
fi

###Send $content_to_mail to $EMAIL
#cat $content_to_mail | mail -s "Patch Management | $(hostname) | $(date +%D)" $EMAIL
 
}

###Actual job starts here!!!
case "$1" in
        prechecks)
            check > $prechecks
            ;;
        postchecks)
            check > $postchecks
            ;;
  
        mon)
            Patch_Mon
            ;;
         
        capture)
            Patch_Capture
            ;;         
        *)
            echo $"Usage: $0 {prechecks|postchecks|mon|capture}"
            exit 1
 
esac
