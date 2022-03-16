#!/bin/bash


#Purpose: perform $2 dns requests to test overhead of tagging for each config
# $1 = number of trials
# $3 = sleep time between each DNS request


# ************** STANDARD PARAMS MUST GO HERE ****************
GIT_DIR=/home/vagrant/software_defined_customization
NCO_DIR=/home/vagrant/software_defined_customization/NCO
EXP_SCRIPT_DIR=/home/vagrant/software_defined_customization/experiment_scripts
EXP_MOD_DIR=/home/vagrant/software_defined_customization/experiment_modules
SIMPLE_SERVER_DIR=/home/vagrant/software_defined_customization/experiment_scripts/client_server
DCA_KERNEL_DIR=/home/vagrant/software_defined_customization/DCA_kernel
DCA_USER_DIR=/home/vagrant/software_defined_customization/DCA_user

SERVER_IP=10.0.0.20
SERVER_PASSWD=vagrant
CLIENT_IP=10.0.0.40
CLIENT_PASSWD=vagrant




# ************** STANDARD PARAMS MUST GO HERE ****************

# Force root
if [[ "$(id -u)" != "0" ]];
then
	echo "This script must be run as root" 1>&2
	exit -1
fi


# client connect to server over ssh, stop dns services, start dnsmasq, then on client run experiment, save data to file

# create file to store batch times
OUTPUT=$EXP_SCRIPT_DIR/logs/batch_base.txt
touch $OUTPUT

sshpass -p "$SERVER_PASSWD" ssh -p 22 -o StrictHostKeyChecking=no root@$SERVER_IP "rmmod layer4_5; systemctl stop dnsmasq.service; systemctl stop systemd-resolved.service; dnsmasq --no-daemon -c 0 >/dev/null 2>&1 &"

sleep 2
rmmod layer4_5

echo "*************** starting baseline batch ***************"

echo starting dns requests

for ((i=1;i<=$1;i++))
do
  echo "DNS test $i"
  total=0;
  for ((j=1;j<=$2;j++))
  do
    query="www.test_base$i$j.com"
    before=$(date '+%s%6N');
    dig @$SERVER_IP -p 53 $query > /dev/null;
    after=$(date '+%s%6N');
    total=$((total+(after-before)));
    sleep $3;
  done
  echo "$((total))" >> $OUTPUT;
done

echo "*************** finished baseline test ***************"


# client connect to server over ssh, kill dnsmasq, install L4.5, restart dnsmasq, client install L4.5, run experiment, save data to file

OUTPUT=$EXP_SCRIPT_DIR/logs/batch_tap.txt
touch $OUTPUT

echo Installing Layer 4.5 on server and client

sshpass -p "$SERVER_PASSWD" ssh -p 22 root@$SERVER_IP "pkill dnsmasq; $DCA_KERNEL_DIR/bash/installer.sh $DCA_KERNEL_DIR; dnsmasq --no-daemon -c 0 >/dev/null 2>&1 &"

sleep 2

$DCA_KERNEL_DIR/bash/installer.sh $DCA_KERNEL_DIR;

sleep 2

echo "*************** starting tap batch ***************"


for ((i=1;i<=$1;i++))
do
  echo "DNS test $i"
  total=0;
  for ((j=1;j<=$2;j++))
  do
    query="www.test_tap$i$j.com"
    before=$(date '+%s%6N');
    dig @$SERVER_IP -p 53 $query > /dev/null;
    after=$(date '+%s%6N');
    total=$((total+(after-before)));
    sleep $3;
  done
  echo "$((total))" >> $OUTPUT;
done

echo "*************** finished tap test ***************"


# client connect to server over ssh, kill dnsmasq, install module, restart dnsmasq, client install module, run experiment, save data to file

OUTPUT=$EXP_SCRIPT_DIR/logs/batch_cust.txt
touch $OUTPUT

sshpass -p "$SERVER_PASSWD" ssh -p 22 root@$SERVER_IP "pkill dnsmasq; cd $EXP_MOD_DIR; make BUILD_MODULE=overhead_test_batch_dns_server.o; insmod overhead_test_batch_dns_server.ko; dnsmasq --no-daemon -c 0 >/dev/null 2>&1 &"


sleep 2

cd $EXP_MOD_DIR;
make BUILD_MODULE=overhead_test_batch_dns_client.o;
insmod overhead_test_batch_dns_client.ko;
cd $EXP_SCRIPT_DIR

sleep 2
echo "*************** starting cust batch ***************"

for ((i=1;i<=$1;i++))
do
  echo "DNS test $i"
  total=0;
  for ((j=1;j<=$2;j++))
  do
    query="www.test_cust$i$j.com"
    before=$(date '+%s%6N');
    dig @$SERVER_IP -p 53 $query > /dev/null;
    after=$(date '+%s%6N');
    total=$((total+(after-before)));
    sleep $3;
  done
  echo "$((total))" >> $OUTPUT;
done

echo "*************** finished cust test ***************"

sleep 2

echo cleaning up

rmmod overhead_test_batch_dns_client
rmmod layer4_5

sshpass -p "$SERVER_PASSWD" ssh -p 22 root@$SERVER_IP "pkill dnsmasq; systemctl start systemd-resolved.service; rmmod overhead_test_batch_dns_server; rmmod layer4_5; exit"


echo generating plot

python3 batch_plot.py
