
STORAGE_DEVICE=$1
if [ "$STORAGE_DEVICE" == "" ]; then
	STORAGE_DEVICE=/dev/sdb
fi	

if [ $(lsblk | grep sdb1 | wc -l) == 0 ]; then
	echo "${STORAGE_DEVICE} is not exist!"
	exit
fi

if [ $(lvs | grep docker-pool | grep docker-vg | wc -l) == 0 ]; then

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

systemctl stop docker

rm -rf /var/lib/docker

/usr/bin/docker-storage-setup

lvs

fi # if [ $(lvs | grep docker-pool | grep docker-vg | wc -l) == 0 ]; then

yum -y erase docker-selinux docker
yum -y remove docker-common.x86_64

yum -y update

if [ $(cat /etc/yum.repos.d/docker.repo | grep ) ]

tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

yum -y install docker-engine

cp docker.service /usr/lib/systemd/system/

systemctl daemon-reload

systemctl enable docker.service

systemctl start docker

docker info

