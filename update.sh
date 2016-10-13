
#!/bin/sh

##############################################################################
########This script is used to update medolution iot platform  ###############
##############################################################################


'''
SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

start_time=$(date +"%s")
_NO_ACCORDS=0
_NO_IHM=0



fatal_exit() {
  if [ -n "$1" ] ; then
    echo "error:  $1$ " >&2
  fi
  echo "failed." >&2
  exit 1
}



while [ -n "$1" ] ; do
case "$1" in

--no-accords)
_NO_ACCORDS=1

;;

--no-ihm)
_NO_IHM=1
;;

--help)
cat <<EOF
Update UseItCloud platform

Usage:  `basename $0`  [<options>]


<options>
  --no-accords      do not update accords platform
  --no-ihm          do not update ihm

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
accords_git_user=root
uic_git_user=root


export DIR_DOCUMENT_ROOT="/var/www/html"
export DIR_DEPOT_ACCORDS="/srv/uicb/platform";
export DIR_DEPOT_ACCORDS_PLATFORM=${DIR_DEPOT_ACCORDS}/accords-platform
export DIR_DEPOT_ACCORDS_CA=${DIR_DEPOT_ACCORDS}/uicb-ca/scripts
export DIR_UIC="/srv/uicb/useitcloud"
export DIR_CMB="${DIR_UIC}/app/cmb"

export DIR_SERVICES="/var/lib/uicb"
export DIR_RUN="/srv/accords/run"
export DIR_CA="/srv/accords/CA"

export DIR_RELEASE="${DIR_SERVICES}/release"
export DIR_VPN="${DIR_SERVICES}/network/vpn"

export SCRIPT_MONITORING="${DIR_SERVICES}/monitoring/service/scripts/srv_monit.sh"
export SCRIPT_LB="${DIR_SERVICES}/lb/service/scripts/srv_cool.sh"
export SCRIPT_VPN="${DIR_VPN}/service/scripts/co_vpn_srv.sh"
export SCRIPT_KEYS="${DIR_SERVICES}/sshkey/co_key_srv.sh"

export LOG_ACCORDS="/var/log/accords/accords.log"
export FILE_ASTAMP_SECRET="/usr/local/etc/accords/astamp.secret"

# vérification dossier générant les certificats
if [ ! -d "${DIR_DEPOT_ACCORDS_CA}" ];then
  echo "Erreur : le dossier ${DIR_DEPOT_ACCORDS_CA} n'existe pas"
  exit 1;
fi

# Useitcloud maintenance
php $DIR_UIC/artisan down

# Stopping platform
co-stop

# Kill all deamons

export PID_LBd=`pgrep -f "${SCRIPT_LB}"`

if [ !  `test -z ${PID_LBd}`];then
    kill -9 ${PID_LBd}
    sleep 1
fi

export PID_MONd=`pgrep -f "${SCRIPT_MONITORING}"`

if [ !  `test -z ${PID_MONd}`];then
    kill -9 ${PID_MONd}
    sleep 1
fi

export PID_VPNd=`pgrep -f "${SCRIPT_VPN}"`

if [ !  `test -z ${PID_VPNd}`];then
    kill -9 ${PID_VPNd}
    sleep 1
fi

export PID_SSHKEYd=`pgrep -f "${SCRIPT_KEYS}"`

if [ !  `test -z ${PID_SSHKEYd}`];then
    kill -9 ${PID_SSHKEYd}
    sleep 1
fi

#accords-platform
cd ${DIR_DEPOT_ACCORDS_PLATFORM}
chown -R ${accords_git_user}:${accords_git_user} ${DIR_DEPOT_ACCORDS_PLATFORM}
chown -R ${accords_git_user}:${accords_git_user} ${DIR_DEPOT_ACCORDS_PLATFORM}/.git*

if [ $_NO_ACCORDS = "0" ] ;then
  sudo -u ${accords_git_user} git pull
  ./master.sh --clean
  ./master.sh --proper-install
  ./master.sh build
  ./master.sh install
fi


#suppression run et recréation run/security
rm -rf ${DIR_RUN}
mkdir -p ${DIR_RUN}/security

#certificats, création si le dossier CA n'existe pas
cd ${DIR_DEPOT_ACCORDS_CA}
if [ ! -d "${DIR_CA}" ];then
  ./gen-certs.sh ca
  ./gen-certs.sh all-components
fi


./gen-certs.sh cosacs prologue --force

./gen-crypto-key.sh crypto --force
#if [ ! -f "/srv/accords/CA/crypto.key" ];then
#  ./gen-crypto-key.sh crypto
#fi

#copie des certificats dans le dossier run/security
#./install-certs.sh --install-dir ${DIR_RUN}/security
./install-certs.sh all
cp ${DIR_CA}/crypto.key ${DIR_RUN}/security/

ldconfig

#run
accords-config create --force --tag-resthost 127.0.0.1
touch ${DIR_RUN}/__rtrace__
#temporaire : modif droits lecture www-data
chmod 440 ${DIR_RUN}/security/curl.key
chown root:www-data ${DIR_RUN}/security/curl.key
chown root:www-data ${DIR_RUN}/security/cosacs/
chown root:www-data ${DIR_RUN}/security/ca-cosacs/
chmod g+w ${DIR_RUN}/security/ca-cosacs/
chmod g+w ${DIR_RUN}/security/cosacs/
chown root:www-data ${DIR_CA}
chmod g+w ${DIR_CA}

#droits ecriture pour /usr/local/lib/accords/py pour root
chmod u+w /usr/local/lib/accords/py/*

#log
> ${LOG_ACCORDS}
chmod +r ${LOG_ACCORDS}

#usr local etc
echo 123456789 > ${FILE_ASTAMP_SECRET}

#cmb-prologue
cd ${DIR_UIC}
rm -rf app/cmb/account/*
rm storage/framework/sessions/*

service apache2 restart

co-start
sleep 3
co-status

# Provider creds, si le fichier provider-creds.sh existe
pcfile=$SCRIPTPATH/provider-creds.sh
[ -f $pcfile ] && bash $pcfile || echo "Pas de fichier $pcfile"

# Update CMB database
cd ${DIR_UIC}
chmod -R 777 bootstrap/cache/
chmod -R 777 storage
rm -rf storage/app/applications/*
rm -rf storage/app/exported_applications/*
rm -rf storage/app/deployments/*

if [ $_NO_IHM = "0" ];then
  sudo -u ${uic_git_user} git pull
fi

sudo -u ${uic_git_user} composer install
sudo -u ${uic_git_user} composer dump-autoload

#redis
redis-cli -h 127.0.0.1 -p 6380 shutdown
redis-server --port 6380 &

service apache2 restart
sudo -u www-data php artisan cache:clear
sudo -u www-data php artisan migrate:refresh --seed
sudo -u www-data php artisan uic:update-public-cloud-data

supervisorctl reread
supervisorctl update
supervisorctl start useitcloud-worker:*

sudo -u www-data php artisan uic:init

## Running Deamons

rm -r ${DIR_SERVICES}
mkdir ${DIR_SERVICES}
cp -r  ${DIR_CMB}/services_cmb/* ${DIR_SERVICES}

if test -e "${SCRIPT_LB}";then
    chmod +x ${SCRIPT_LB}
    nohup sh ${SCRIPT_LB} > ${DIR_SERVICES}/lb/service/scripts/nohup.lb.log  2>&1 &
fi


if test -e "${SCRIPT_MONITORING}";then
    rm /etc/nagios3/conf.d/uicb
    ln -s ${DIR_SERVICES}/monitoring/service/data/conf.d /etc/nagios3/conf.d/uicb
    cat > /etc/logrotate.d/uicb_monit <<END
    ${DIR_SERVICES}/monitoring/service/scripts/nohup.monitor.log {
      rotate 10
      daily
      compress
      size 2M
      missingok
      notifempty
      create 0640 root root
    }
END

    chmod +x ${SCRIPT_MONITORING}
    nohup sh ${SCRIPT_MONITORING} > ${DIR_SERVICES}/monitoring/service/scripts/nohup.monitor.log 2>&1 &
fi

if test -e "${SCRIPT_VPN}";then
    chmod +x ${SCRIPT_VPN}
    nohup sh ${SCRIPT_VPN} > ${DIR_SERVICES}/network/vpn/service/scripts/nohup.vpn.log  2>&1 &
fi

if test -e "${SCRIPT_KEYS}";then
    chmod +x ${SCRIPT_KEYS}
    nohup sh ${SCRIPT_KEYS} > ${DIR_SERVICES}/sshkey/nohup.sshkey.log  2>&1 &
fi

## Configure VPN
# surcharge uicbDocRoot et uic_basedir
echo "export uicbDocRoot='${DIR_DOCUMENT_ROOT}'" >> ${DIR_VPN}/service/scripts/netvpn.cfg
echo "export uic_basedir='${DIR_UIC}'" >> ${DIR_VPN}/service/scripts/netvpn.cfg

## Configure Release
chown -R www-data:www-data ${DIR_RELEASE}/account
chown -R www-data:www-data ${DIR_RELEASE}/req
chmod -R 700 ${DIR_RELEASE}/account
chmod -R 700 ${DIR_RELEASE}/req

# Useitcloud maintenance
php $DIR_UIC/artisan up

end_time=$(date +"%s")
diff=$(($end_time-$start_time))

echo "\n"
echo  "Duration:  $(($diff / 3600 ))  hours $((($diff % 3600) / 60)) minutes  $(($diff % 60))  seconds elapsed."

'''


