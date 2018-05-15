#!/bin/bash
export MYSQL_PWD="${master_db_pass}"
MYSQL_CMD="mysql -h ${master_db_host} -u ${master_db_user} "
sudo yum install -y mysql56

$MYSQL_CMD -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
$MYSQL_CMD -e "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%' IDENTIFIED BY '${db_pass}';FLUSH PRIVILEGES;"