#!/bin/bash
#################################################################################
############## INSTALL SCRIPT FOR MEDOLUTION IoT PLATFORM #######################
#################################################################################

### Prerequisites
#Ubuntu 16.04 with non root sudo user



start_time=$(date +"%s")
sudo apt-get clean
sudo apt-get update


###Config params

export USER=`whoami`
export MEDOLUTION_IOT_VERSION=0.0.0-beta
export PUBLIC_DOMAIN=medolutioniot.useitcloud.com
export BITBUCKET_USER=Bechir
export BITBUCKET_PASSWORD=Ta122016$
export DEBIAN_FRONTEND="noninteractive"
export GULP_LOG_FILE=/tmp/loggulp

export BRANCH=master
sudo apt-get install -y realpath
export INST_SCRIPT=`realpath $0`
export INST_SCRIPT_PATH=`dirname $INST_SCRIPT`
export HOSTNAME=`hostname`


sudo chmod 666 /etc/hosts
echo 127.0.0.1 $HOSTNAME >> /etc/hosts
sudo chmod 644 /etc/hosts



#database
export MYSQL_ADMIN_PASSWD=root
export DB_DATABASE=medolutioniot
export DB_USERNAME=mediot
export DB_PASSWORD=password
export MARIADB_VERSION='10.1'
export DIR_MEDOLUTION=~/.sources
sudo rm -rf $DIR_MEDOLUTION
mkdir -p $DIR_MEDOLUTION
cd $DIR_MEDOLUTION
git clone -b $BRANCH https://$BITBUCKET_USER:$BITBUCKET_PASSWORD@bitbucket.org/Bechir/medolutioniot.git
##log
sleep 10
sudo apt install ccze
#Install npm, bower, php-mycrypt for Ubuntu 16.04
sudo apt-get -y install apache2
sudo apt-get -y install nodejs
sudo apt-get -y install npm


#sudo chown -R $USER /usr/local/lib/node_modules



sudo ln -s /usr/bin/nodejs /usr/bin/node

sudo -u root npm install -g bower
sudo -u root npm install -g gulp


sudo apt-get update
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

###C######## Configure Apache2
############ Configuration des fichiers conf ######
sudo rm /etc/apache2/sites-enabled/*
sudo cp $DIR_MEDOLUTION/medolutioniot/conf/medolution_apache.conf /etc/apache2/sites-available/medolution.conf
sudo sed -i "s|DIR_MEDOLUTION|$DIR_MEDOLUTION/medolutioniot|" /etc/apache2/sites-available/medolution.conf
sudo sed -i "s|ServerName|ServerName $PUBLIC_DOMAIN|" /etc/apache2/sites-available/medolution.conf
sudo sed -i "s|ServerAlias|ServerAlias $PUBLIC_DOMAIN|" /etc/apache2/sites-available/medolution.conf


sudo chmod 666 /etc/apache2/apache2.conf
cat >> /etc/apache2/apache2.conf << END
<Directory $DIR_MEDOLUTION>
  Options Indexes FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>
END

sudo chmod 660 /etc/apache2/apache2.conf
###end conf file
sudo a2ensite medolution
sudo a2enmod rewrite
sudo service apache2 restart


###Composer install
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/bin --filename=composer


#### MariaDB server
export DEBIAN_FRONTEND="noninteractive"

MARIADB_VERSION='10.1'
# Import repo key
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db


sudo apt-get install -y software-properties-common
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://ftp.utexas.edu/mariadb/repo/10.1/ubuntu xenial main'


# Update
sudo apt-get update
# Install MariaDB without password prompt
sudo debconf-set-selections <<< "maria-db-$MARIADB_VERSION mysql-server/root_password password $MYSQL_ADMIN_PASSWD"
sudo debconf-set-selections <<< "maria-db-$MARIADB_VERSION mysql-server/root_password_again password $MYSQL_ADMIN_PASSWD"

sudo apt-get install -qq mariadb-server


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




npm update -g minimatch@3.0.2
npm update -g minimatch@3.0.2
npm update -g graceful-fs@^4.0.0


npm install
bower install

sudo chown -R $(whoami) /home/$USER/.config

gulp watch > $GULP_LOG_FILE &
sudo -u www-data php artisan cache:clear



sudo chmow -R $USER:$USER storage/
sudo chmod -R 777 storage
sudo -u $USER php artisan key:generate


#sudo -u www-data php artisan migrate:refresh --seed





## configure alias
## DO NOT USE FOR PRODUCTION ENVIRONMENT

echo "alias errlog='tail -f /var/log/apache2/error.log | ccze -A'"  >>  ~/.bashrc
echo "alias accesslog='tail -f /var/log/apache2/access.log | ccze -A'"  >> ~/.bashrc
echo "alias lalog='sudo tail -f /$DIR_MEDOLUTION/medolutioniot/storage/logs/laravel.log | ccze -A'" >> ~/.bashrc
echo "alias medsrc='cd $DIR_MEDOLUTION/medolutioniot'" >> ~/.bashrc
echo "alias updatemediot='bash $DIR_MEDOLUTION/medolutioniot/update.sh'" >> ~/.bashrc
echo "alias updatemediot='alias c='clear''" >> ~/.bashrc
source ~/.bashrc



##### Set UP the SSL Certificate   Configure once manually
'''
sudo apt-get update
sudo apt-get -y install python-letsencrypt-apache
sudo letsencrypt --apache -d $PUBLIC_DOMAIN --register-unsafely-without-email


#cron
#cron
line="30 2 * * 1 /usr/bin/letsencrypt renew >> /var/log/le-renew.log 2>&1"
(sudo crontab -u root -l; echo "$line" ) | sudo crontab -u root -

'''


end_time=$(date +"%s")
diff=$(($end_time-$start_time))

echo "\n"
echo  "Duration:  $(($diff / 3600 ))  hours $((($diff % 3600) / 60)) minutes  $(($diff % 60))  seconds elapsed."