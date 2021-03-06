#!/bin/sh

# usage: cocktail_backup.sh save_path days
# ./cocktail-backup.sh /nas/BACKUP/db 10

export KUBECONFIG=/etc/kubernetes/admin.conf

CURRENT_DATE=`date '+%Y%m%d'`
CURRENT_TIME=`date '+%Y%m%d_%H%M%S'`

COCKTAIL_BACKDIR="$1"

COCKTAIL_NS=cocktail-system

error_exit() {
    echo "error: ${1:-"unknown error"}" 1>&2
    exit 1
}

verify_prereqs() {
    echo "Verifying Prerequisites"

    if [ ! -d $COCKTAIL_BACKDIR ]; then
        error_exit "Can't access cmdb backup directory $COCKTAIL_BACKDIR"
    fi

    chk_cmdb=`kubectl get sts -n $COCKTAIL_NS | grep api-cmdb | wc -l`

    if [ "${chk_cmdb}" -eq 1 ]; then
        acloud_cmdb_pod=`kubectl get pods -n $COCKTAIL_NS | grep cocktail-api-cmdb-0 | awk '{print $1}'`
        sqldumpcmd='/usr/bin/mysqldump'
    else
        acloud_cmdb_pod=`kubectl get pods -n $COCKTAIL_NS | grep api-cmdb | awk '{print $1}'`
        sqldumpcmd='/usr/bin/mysqldump'
    fi

        if [ -z $acloud_cmdb_pod ]; then
                echo "Can't get acloud cmdb pod name. exit."
                exit 1;
        fi
}

main() {
    if [ "$#" -ne 2 ]; then
                echo "./cocktail-backup.sh /nas/BACKUP/ 10"
        error_exit "Illegal number of parameters. You must pass backup directory path and number of days to keep backups"
    fi

    verify_prereqs

    echo "Getting ready to backup to  cmdb($COCKTAIL_BACKDIR)"

    kubectl exec "$acloud_cmdb_pod" -n $COCKTAIL_NS -- sh -c "${sqldumpcmd} --single-transaction --databases acloud builder -u root -pC0ckt@ilWks@2 > /tmp/acloud_cmdb_dump.$CURRENT_TIME.sql"
    sudo kubectl cp $COCKTAIL_NS/$acloud_cmdb_pod:/tmp/acloud_cmdb_dump.$CURRENT_TIME.sql $COCKTAIL_BACKDIR/acloud_cmdb_dump.$CURRENT_TIME.sql
    kubectl exec -n $COCKTAIL_NS $acloud_cmdb_pod -- sh -c "rm /tmp/acloud_cmdb_dump.$CURRENT_TIME.sql"

    sudo gzip $COCKTAIL_BACKDIR/acloud_cmdb_dump.$CURRENT_TIME.sql

    echo "acloud cmdb dump succeeded."

    sudo find $COCKTAIL_BACKDIR -name "*cmdb_dump*" -mtime +$2 | xargs rm -rf

    sudo find /data/log -name "*" -mtime +30 | xargs rm -rf

    echo "Backup completed."
}

main "${@}"