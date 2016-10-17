#!/bin/bash
#################################################################################
############## Update SCRIPT FOR MEDOLUTION IoT PLATFORM #######################
#################################################################################

start_time=$(date +"%s")


SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`




_NO_OPT1=0
_NO_OPT2=0



fatal_exit() {
  if [ -n "$1" ] ; then
    echo "error:  $1$ " >&2
  fi
  echo "failed." >&2
  exit 1
}



while [ -n "$1" ] ; do
case "$1" in

--no-opt1)
_NO_OPT1=1

;;

--no-opt2)
_NO_OPT2=1
;;

--help)
cat <<EOF
Update UseItCloud platform

Usage:  `basename $0`  [<options>]


<options>
  --no-opt1      do not update opt1
  --no-opt2          do not update opt2

  --help            - print this text

EOF
exit 1
;;

*)
fatal_exit "Invalid option: $1"
;;

esac
shift
done



# utilisateur utilisé pour git pull et composer install

export USER=`whoami`
export mediot_git_user=$USER
export DIR_DOCUMENT_ROOT="/var/www/html"
export DIR_MEDOLUTION=~/sources/medolutioniot


# medolution iot platform maintenance mode
sudo -u cloud php artisan down




#cmb-prologue
cd ${DIR_MEDOLUTION}
sudo rm storage/framework/sessions/*

sudo service apache2 restart


# Update medolution iot database
cd ${DIR_UIC}
chmod -R 777 bootstrap/cache/
chmod -R 777 storage


sudo -u ${uic_git_user} git pull


sudo -u ${mediot_git_user} composer install
sudo -u ${mediot_git_user} composer dump-autoload


service apache2 restart
sudo -u www-data php artisan cache:clear
#sudo -u www-data php artisan migrate:refresh --seed



# Useitcloud maintenance
sudo -u cloud php artisan up




end_time=$(date +"%s")
diff=$(($end_time-$start_time))

echo "\n"
echo  "Duration:  $(($diff / 3600 ))  hours $((($diff % 3600) / 60)) minutes  $(($diff % 60))  seconds elapsed."



