#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if (( $# != 5 )); then
    echo "###################################################################"
    echo "Illegal number of parameters"
    echo "--------------------------------------"
    echo "Usage $0 IPaddr/CIDR Gateway Hostname auriga.services DNS"
    echo "Example $0 10.10.10.10/24 10.10.10.254 10-v-30-ocl99 jellyfish.inc 8.8.8.8,8.8.4."
    echo "###################################################################"
    exit
fi

#Arguments
# $1 IP/CIDR
# $2 Gateway
# $3 Hostname
# $4 domainname
# $5 DNS Server (comma delimitied)

#Check Network connectivity, if not up refuse to make any modifications
ip link set dev ens192 up

LINKUP=`ip link | grep ^2: | grep "DOWN\|UNKOWN" | wc -l`
if (( $LINKUP != 0 )); then
   echo "Ethernet Link seems to been down... exiting!"
   exit
fi

OUTPUT="/etc/netplan/01-netcfg.yaml"

echo "network:" > $OUTPUT
echo "    version: 2" >> $OUTPUT
echo "    renderer: networkd" >> $OUTPUT
echo "    ethernets:" >> $OUTPUT
echo "        ens192:" >> $OUTPUT
echo "            dhcp4: no" >> $OUTPUT
echo "            addresses: [$1]" >> $OUTPUT
echo "            gateway4:  $2" >> $OUTPUT
echo "            nameservers:" >> $OUTPUT
echo "             addresses: [$5]" >> $OUTPUT

#get rid of old config stuff
rm -f /etc/netplan/50-cloud-init.yaml

#add new ip address to hosts file
#substitute oldhostname remanants in /etc/hosts
IPvalue=`echo $1 | cut -d"/" -f 1`
OLDhostname=`cat /etc/hostname`
sed -i "s/$OLDhostname/$3/g" /etc/hosts
echo $IPvalue $3    >> /etc/hosts
echo $IPvalue $3.$4 >> /etc/hosts

#setup hostname
hostnamectl set-hostname $3
echo $3.$4 > /etc/hostname

#set correct hostname for syslog facility
sed -i "s/REPLACEHOSTNAME/$3.$4/g" /etc/rsyslog.conf

#tidy up old ssh key remants
/bin/rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

reboot
