#!/bin/bash
#################################################################################
############## INSTALL SCRIPT FOR MEDOLUTION IoT PLATFORM #######################
#################################################################################


sudo apt-get clean
sudo apt-get update


###Config params

export USER=`whoami`
export MEDOLUTION_IOT_VERSION=0.0.0-beta
export BITBUCKET_USER=Bechir
export BITBUCKET_PASSWORD=XXXXXX
export DEBIAN_FRONTEND="noninteractive"
export GULP_LOG_FILE=/tmp/loggulp

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
export MARIADB_VERSION='10.1'
export DIR_MEDOLUTION=~/sources
sudo rm -rf $DIR_MEDOLUTION
mkdir -p $DIR_MEDOLUTION
cd $DIR_MEDOLUTION
git clone -b $BRANCH https://$BITBUCKET_USER:$BITBUCKET_PASSWORD@bitbucket.org/Bechir/medolutioniot.git
##log

sudo apt install ccze
#Install npm, bower, php-mycrypt for Ubuntu 16.04
sudo apt-get -y install apache2
sudo apt-get -y install nodejs
sudo apt-get -y install npm
sudo chown -R $(whoami) /usr/local/lib/node_modules/

sudo ln -s /usr/bin/nodejs /usr/bin/node

npm install -g bower
npm install -g gulp
sudo apt-get -y install php7.0 php7.0-cli libapache2-mod-php7.0 php-mcrypt php7.0-mysql
sudo apt-get -y install php7.0-mysql
sudo apt-get -y install php7.0-json
sudo apt-get -y install php7.0-curl
sudo apt-get -y install php7.0-ldap
sudo apt-get -y install php7.0-xmlrpc
sudo apt-get -y install php7.0-mbstring
sudo apt-get -y install php7.0-dom
sudo apt-get -y install php7.0-gd
sudo apt-get -y install php7.0-soap
###configure Apache2

############ configuration des fichiers conf ######
sudo rm /etc/apache2/sites-enabled/*
sudo cp $DIR_MEDOLUTION/medolutioniot/conf/medolution_apache.conf /etc/apache2/sites-available/medolution.conf
sudo sed -i "s|DIR_MEDOLUTION|$DIR_MEDOLUTION/medolutioniot|" /etc/apache2/sites-available/medolution.conf

sudo chmod 666 /etc/apache2/apache2.conf
cat >> /etc/apache2/apache2.conf << END
<Directory $DIR_MEDOLUTION/medolutioniot>
  Options Indexes FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>
END

sudo chmod 660 /etc/apache2/apache2.conf
###end conf file
sudo a2ensite medolution
sudo service apache2 restart


###Composer install
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/bin --filename=composer


#### MariaDB server
export DEBIAN_FRONTEND="noninteractive"

MARIADB_VERSION='10.1'
# Import repo key
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db

# Add repo for MariaDB
sudo add-apt-repository "deb [arch=amd64,i386] http://mirrors.accretive-networks.net/mariadb/repo/$MARIADB_VERSION/ubuntu trusty main"

# Update
sudo apt-get update
# Install MariaDB without password prompt
sudo debconf-set-selections <<< "maria-db-$MARIADB_VERSION mysql-server/root_password password $MYSQL_ADMIN_PASSWD"
sudo debconf-set-selections <<< "maria-db-$MARIADB_VERSION mysql-server/root_password_again password $MYSQL_ADMIN_PASSWD"

sudo apt-get install -qq mariadb-server
sudo apt-get install -y mariadb-client-core-10.0


#####################Modify root password ################################
MYSQL=`which mysql`
Q1="use mysql;"
Q2="update user set plugin='' where User='root';"
Q3="update user set Password=PASSWORD('$MYSQL_ADMIN_PASSWD') where User='root';"
Q4="GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ADMIN_PASSWD' WITH GRANT OPTION;"
Q5="FLUSH PRIVILEGES;"

SQL="${Q1}${Q2}${Q3}${Q4}${Q5}"

$MYSQL -uroot -p$MYSQL_ADMIN_PASSWD -e "$SQL"

sudo service mysql restart




cd $DIR_MEDOLUTION/medolutioniot
sudo chown -R www-data:www-data storage bootstrap/cache

cp .env.example .env

sed -i "s/DB_DATABASE=/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env



sudo chown -R $(whoami) /home/$USER/.composer

sudo -u $USER composer install
sudo -u $USER composer dump-autoload

sudo -u $USER php artisan key:generate

sudo chown -R $(whoami) /home/$USER/.config
npm install
bower install
gulp watch > $GULP_LOG_FILE &
sudo -u www-data php artisan cache:clear

#sudo -u www-data php artisan migrate:refresh --seed
















