
STORAGE_DEVICE=$1
if [ "$STORAGE_DEVICE" == "" ]; then
	STORAGE_DEVICE=/dev/sdb
fi	

if [ $(lsblk | grep sdb1 | wc -l) == 0 ]; then
	echo "${STORAGE_DEVICE} is not exist!"
	exit
fi

if [ $(lvs | grep docker-pool | grep docker-vg | wc -l) == 0 ]; then
echo "setup direct disk mode"
echo "-------------------------------------------------------------------------"


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

yum -y update

if [ $(cat /etc/yum.repos.d/docker.repo | grep yum.dockerproject.org | wc -l ) == 0 ]; then

tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

fi

yum list installed | grep docker | awk -v N=1 '{print $N}' | xargs yum -y remove

systemctl stop docker
systemctl disable docker.service

echo "installing docker ... "
echo "-------------------------------------------------------------------------"
yum -y install docker-engine

echo "replacing docker.service"
echo "-------------------------------------------------------------------------"
cp docker.service /usr/lib/systemd/system/
cp docker-storage /etc/sysconfig/

echo "reload docker.service"
echo "-------------------------------------------------------------------------"
systemctl daemon-reload

echo "enable docker.service"
echo "-------------------------------------------------------------------------"
systemctl enable docker.service

echo "start docker.service"
echo "-------------------------------------------------------------------------"
systemctl start docker

echo "show docker info"
echo "-------------------------------------------------------------------------"
docker info


