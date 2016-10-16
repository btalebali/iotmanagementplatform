#!/bin/bash
#################################################################################
############## INSTALL SCRIPT FOR MEDOLUTION IoT PLATFORM #######################
#################################################################################


sudo apt-get clean
sudo apt-get update


###Config params

export USER=cloud
export MEDOLUTION_IOT_VERSION=0.0.0-beta
export BITBUCKET_USER=Bechir
export BITBUCKET_PASSWORD=Ta122016$


export BRANCH=master
sudo apt-get install -y realpath
export INST_SCRIPT=`realpath $0`
export INST_SCRIPT_PATH=`dirname $INST_SCRIPT`
export HOSTNAME=`hostname`
sudo echo 127.0.0.1 $HOSTNAME >> /etc/hosts


#database
export MYSQL_ADMIN_PASSWD=root
export DB_DATABASE=medolutioniot
export DB_USERNAME=mediot
export DB_PASSWORD=password

export DIR_MEDOLUTION=~/sources
rm -rf $DIR_MEDOLUTION
mkdir -p $DIR_MEDOLUTION
cd $DIR_MEDOLUTION
git clone -b $BRANCH https://$BITBUCKET_USER:$BITBUCKET_PASSWORD@bitbucket.org/Bechir/medolutioniot.git 

#Install npm, bower, php-mycrypt for Ubuntu 16.04
sudo apt-get -y install apache2 nodejs npm
sudo nmp install -g bower
sudo apt-get -y install php php7.0-cli libapache2-mod-php php-mcrypt php-mysql
###configure Apache2

############ configuration des fichiers conf ######
sudo rm /etc/apache2/sites-enabled/*
sudo cp $DIR_MEDOLUTION/medolutioniot/conf/medolution_apache.conf /etc/apache2/sites-available/medolution.conf
sed -i "s|DIR_MEDOLUTION|$DIR_MEDOLUTION|" /etc/apache2/sites-available/medolution.conf


sudo cat >> /etc/apache2/apache2.conf << END
<Directory $DIR_MEDOLUTION>
  Options Indexes FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>
END
###end conf file
sudo a2ensite medolution
sudo service apache2 restart







##Database


sudo apt-get install -y mysql-server



mysql -f -uroot -p$MYSQL_ADMIN_PASSWD -e "create database $DB_DATABASE;"
mysql -f -uroot -p$MYSQL_ADMIN_PASSWD -e "CREATE USER '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -f -uroot -p$MYSQL_ADMIN_PASSWD -e "GRANT ALL PRIVILEGES ON uicb.* TO '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD';FLUSH PRIVILEGES;"



cd $INST_SCRIPT_PATH
chown -R www-data:www-data storage bootstrap/cache

cp .env.example .env

sed -i "s/DB_DATABASE=/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env

###Composer install 
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/bin --filename=composer




sudo -u root composer install
sudo -u root composer dump-autoload

sudo -u www-data php artisan key:generate


sudo -u root npm install
sudo -u root bower install
sudo nohup gulp watch 2>&1
sudo -u www-data php artisan cache:clear
sudo -u www-data php artisan migrate:refresh --seed
















