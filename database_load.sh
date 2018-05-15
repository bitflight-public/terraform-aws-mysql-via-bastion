#!/bin/bash
export MYSQL_PWD="${master_db_pass}"
MYSQL_CMD="mysql -h ${master_db_host} -u ${master_db_user} "
LOADED=$($MYSQL_CMD -N -B -e 'select count(*) from information_schema.tables where table_type = "BASE TABLE" and table_schema = "${db_name}";')
[ $LOADED == 0 ] && zcat /tmp/{database_gz} | $MYSQL_CMD ${db_name}

exit 0