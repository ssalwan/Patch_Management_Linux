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
export REPO=/data04/$b
export patch_file=$REPO/patches_$b
export content_to_mail=$REPO/Content_to_mail_$b
export prechecks=$REPO/prechecks_$b.txt
export postchecks=$REPO/postchecks_$b.txt
export diff_checks=$REPO/diff-checks_$b.txt
#export install_loc=/etc/init.d/patch_manager
export EMAIL=shubham.salwan@iongroup.com



###Create the Repository
if [[ ! -d $REPO ]]
then
mkdir -p $REPO
fi

###Touch files
#touch $prechecks
#touch $postchecks

#Reset previous variables
unset tecreset os internalip externalip nameserver

###Prechecks

###Install the chkconfig configuration
install ()
{
in=$REPO/../install-$b
mkdir -p $in
crontab -l > $in/crontab.txt
echo "################################## ASP TICKET ##################################" >> $in/crontab.txt
echo "15 0 * * 6 /data04/wss_alerts/patch_manager.sh prechecks" >> $in/crontab.txt
echo "@reboot sleep 60 && /data04/wss_alerts/patch_manager.sh postchecks" >> $in/crontab.txt
echo "@reboot sleep 100 && /data04/wss_alerts/patch_manager.sh build" >> $in/crontab.txt
echo "################################################################################" >> $in/crontab.txt
crontab $in/crontab.txt


}
check ()
{

# Check if connected to Internet or not
ping -c 1 google.com &> /dev/null && echo -e "Internet:  Connected" || echo -e "Internet:  Disconnected"
echo " "

# Check OS Type
os=$(uname -o)
echo -e "Operating System Type :"  $os
echo " "

# Check OS Release Version and Name
cat /etc/os-release | grep 'NAME\|VERSION' | grep -v 'VERSION_ID' | grep -v 'PRETTY_NAME' > /tmp/osrelease
echo -n -e "OS Name :"   && cat /tmp/osrelease | grep -v "VERSION" | cut -f2 -d\"
echo " "

echo -n -e "OS Version :"  `cat /etc/os-release | grep -w VERSION | cut -f2 -d=`
echo " "
echo " "

# Check Architecture
architecture=$(uname -m)
echo -e "Architecture :"  $architecture
echo " "

# Check hostname
echo -e "Hostname :"  $HOSTNAME
echo " "

# Check Internal IP
internalip=$(hostname -I)
echo -e "Internal IP :"  $internalip
echo " "

# Check External IP
#externalip=$(curl -s ipecho.net/plain;echo)
#echo -e "External IP :  "$externalip
#echo " "

# Check DNS
nameservers=$(cat /etc/resolv.conf | sed '1 d' | awk '{print $2}')
echo -e "Name Servers :"  $nameservers
echo " "

#Check total CPU processors
echo -e "CPU processors :"  `grep -c ^processor /proc/cpuinfo`
echo " "

# Check total RAM and SWAP
echo -e "Physical Memory :"  `cat /proc/meminfo  | grep MemTotal | awk {'print $2 " " $3'}`
echo " "

echo -e "Swap Memory :"  `cat /proc/meminfo  | grep SwapTotal | awk {'print $2 " " $3'}`
echo " "

# Check Disk Usages
echo -e "Disk Usages :"
echo -e "$(df -hTP | grep -E "ext|nfs"| awk {'print $1 " " $2 " " $3 " " $7'} | column -t)"
echo " "

# Total mounts
echo -e " Mounts listed below : "
echo " ****************************************************************************************************************************************************************************************************** "
mount |grep -E "ext|nfs" | sort -u
echo " ****************************************************************************************************************************************************************************************************** "

# Number of mounts
echo -e "Number of mount points :"   $(mount |grep -E "ext|nfs" | sort -u | wc -l)
echo " "


###List of the running services in RHEL 7+
echo -e "List of all the running services :"
echo " ****************************************************************************************************************************************************************************************************** "
systemctl | grep running | sort |grep -vE "session" | awk {'print $1 " " $2 " " $3 " " $4'} | column -t
echo " ****************************************************************************************************************************************************************************************************** "

# Remove Temporary Files
rm /tmp/osrelease
shift $(($OPTIND -1))

}

###Capture if the patches got installed today
Patch_Capture()
{

###Touch files and null if previous exist
touch $patch_file
>$patch_file

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


###Load the num of patches variable
cat $patch_file | wc -l > $REPO/num_patches

}


###Monitor if the server got rebooted and  patches got installed on the current date
Patch_Mon()
{

###Touch files and null if previous exist
touch $REPO/sdiff_$b
touch $content_to_mail
>$REPO/sdiff_$b
>$content_to_mail


###Find out if server got rebooted on the current date?
if [[ `who -b | awk '{print $3}'` = $(date +%F) ]]
then
  echo "Server rebooted today : Yes " >> $content_to_mail
  echo " " >> $content_to_mail
  echo " " >> $content_to_mail
else
  echo "Server rebooted today : No " >> $content_to_mail
  echo " " >> $content_to_mail
  echo " " >> $content_to_mail
fi


###Difference in prechecks and postchecks?
if [ -f $prechecks ] && [ -f $postchecks ]
then
    diff $prechecks $postchecks > $diff_checks
    if [[ -s $diff_checks ]]
       then
       echo "Difference in checks found : Yes " >> $content_to_mail
       sdiff -s --width=200 $prechecks $postchecks > $REPO/sdiff_$b
       echo " " >> $content_to_mail
       echo " " >> $content_to_mail
       echo " " >> $content_to_mail
       echo " ################################################################################################################################ " >> $content_to_mail
       cat $REPO/sdiff_$b >> $content_to_mail
       echo " ################################################################################################################################ " >> $content_to_mail
       echo " " >> $content_to_mail

       else
       echo "Difference in checks found : No" >> $content_to_mail
       echo " " >> $content_to_mail
    fi

fi




###Display if the patches got installed on the current date.
if [[ `cat $patch_file` = "No patches installed today" ]]
then
  echo "No patches installed today" >> $content_to_mail
else
  echo " " >> $content_to_mail
  echo "We see $(cat $REPO/num_patches) patches have been installed today " >> $content_to_mail
  echo " " >> $content_to_mail
  echo " " >> $content_to_mail
  echo " ####################################################################################################################################### " >> $content_to_mail
  cat $patch_file >> $content_to_mail
  echo " ####################################################################################################################################### " >> $content_to_mail
fi

###Send $content_to_mail to $EMAIL
cat $content_to_mail | mail -s "Patch Management | $(hostname) | $(date +%D)" $EMAIL

}

###Actual job starts here!!!
case "$1" in
        install)
            ###Install the chkconfig configuration
            install > $REPO/../install.log
            ;;
        prechecks)
            ###Touch files
            touch $prechecks
            check > $prechecks
            ;;
        postchecks)
            ###Touch files
            touch $postchecks
            check > $postchecks
            ;;

        mon)
            Patch_Mon
            ;;

        capture)
            Patch_Capture
            ;;

        build)
            Patch_Capture
            Patch_Mon
            ;;

        *)
            echo $"Usage: $0 {install|prechecks|postchecks|build|capture|mon}"
            exit 1

esac

