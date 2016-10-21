
STORAGE_DEVICE=$1
if [ "$STORAGE_DEVICE" == "" ]; then
	STORAGE_DEVICE=/dev/sdb
fi	

if [ ! -f ${STORAGE_DEVICE} ]; then
	echo "${STORAGE_DEVICE} is not exist!"
	exit
fi

fdisk ${STORAGE_DEVICE} <<EOF
d

n
p
1



t
8e

w
EOF

yum -y install docker

pvcreate ${STORAGE_DEVICE}1

vgcreate docker-vg ${STORAGE_DEVICE}1

if [ $(cat /etc/sysconfig/docker-storage-setup | grep docker-vg | wc -l) == 0  ]; then

echo '
VG=docker-vg
SETUP_LVM_THIN_POOL=yes
DATA_SIZE=70%FREE
' >> /etc/sysconfig/docker-storage-setup

fi

rm -rf /var/lib/docker

/usr/bin/docker-storage-setup

lvs

