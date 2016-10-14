#!/bin/bash
#################################################################################
############## INSTALL SCRIPT FOR MEDOLUTION IoT PLATFORM #######################
#################################################################################


apt-get clean
apt-get update


###Config params
export USER='bechir'
export MEDOLUTION_IOT_VERSION='0.0.0-beta'


apt-get install -y realpath
export INST_SCRIPT=`realpath $0`
export INST_SCRIPT_PATH=`dirname $INST_SCRIPT`
export HOSTNAME=`hostname`

#database
export MYSQL_ADMIN_PASSWD='root'

export DB_DATABASE='medolutioniot'
export DB_USERNAME='mediot'
export DB_PASSWORD='password'
echo 127.0.0.1 $HOSTNAME >> /etc/hosts


sed -i "s/DB_DATABASE=/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env


mysql -f -uroot -p$MYSQL_ADMIN_PASSWD -e "create database $DB_DATABASE;"
mysql -f -uroot -p$MYSQL_ADMIN_PASSWD -e "CREATE USER '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -f -uroot -p$MYSQL_ADMIN_PASSWD -e "GRANT ALL PRIVILEGES ON uicb.* TO '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD';FLUSH PRIVILEGES;"






#Install npm, bower, php-mycrypt for Ubuntu 16.04
sudo apt-get -y install apache2
sudo apt-get install php7.0-mysql



cd $INST_SCRIPT_PATH
chown -R www-data:www-data storage bootstrap/cache

cp .env.example .env
sudo -u root composer install
sudo -u root composer dump-autoload

sudo -u www-data php artisan key:generate


sudo -u root npm install
sudo -u root bower install
sudo nohup gulp watch 2>&1
sudo -u www-data php artisan cache:clear
sudo -u www-data php artisan migrate:refresh --seed
service apache2 restart













