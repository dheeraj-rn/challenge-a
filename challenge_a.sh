#!/bin/bash

echo "Enter domain name: "
read domain_name
mysql_password=root@1234

sudo apt update
dpkg -s php7.2-fpm &> /dev/null
if [ $? -eq 0 ]; then
    echo "php is installed!"
else
    echo "Installing php-fpm!"
    sudo apt install php7.2-fpm -y
fi

dpkg -s php-mysql &> /dev/null
if [ $? -eq 0 ]; then
    echo "php-mysql is installed!"
else
    echo "Installing php-mysql!"
    sudo apt install php-mysql -y
fi

dpkg -s mysql-server &> /dev/null
if [ $? -eq 0 ]; then
    echo "mysql-server is installed!"
else
    echo "Installing mysql-server!"
    echo "mysql-server mysql-server/root_password password $mysql_password" | sudo debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $mysql_password" | sudo debconf-set-selections
    sudo apt install mysql-server -y
fi

dpkg -s nginx &> /dev/null
if [ $? -eq 0 ]; then
    echo "nginx is installed!"
else
    echo "Installing nginx!"
    sudo apt install nginx -y
fi

mysql -uroot -p$mysql_password -e 'create database `'"$domain_name"_db'`;'

sudo echo "server {
        listen 80;
        listen [::]:80;

        root /var/www/$domain_name/html;
        index index.php index.html index.htm index.nginx-debian.html;

        server_name $domain_name www.$domain_name;

        location / {
                try_files "'$'"uri "'$'"uri/ =404;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        }
}" > $domain_name
sudo chmod 644 $domain_name
sudo mv $domain_name /etc/nginx/sites-available/
sudo chown root:root /etc/nginx/sites-available/$domain_name
sudo ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/

echo "Adding $domain_name to /etc/hosts"
sudo sh -c "echo 127.0.0.1 $domain_name >> /etc/hosts"

sudo mkdir -p /var/www/$domain_name/html
sudo chown -R $USER:$USER /var/www/$domain_name/html
sudo chmod -R 755 /var/www/$domain_name

echo "Downloading latest wordpress"
wget https://wordpress.org/latest.zip

dpkg -s unzip &> /dev/null
if [ $? -eq 0 ]; then
    echo ""
else
    echo "Installing unzip!"
    sudo apt install unzip -y
fi

unzip latest.zip
echo "Installing Wordpress!"
mv wordpress/* /var/www/$domain_name/html/

echo "Generating wp-config.php"
echo "<?php" > /var/www/$domain_name/html/wp-config.php
echo "define( 'DB_NAME', '"$domain_name"_db' );
define( 'DB_USER', 'root' );
define( 'DB_PASSWORD', '$mysql_password' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );" >> /var/www/$domain_name/html/wp-config.php
curl https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/$domain_name/html/wp-config.php
echo "\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}
require_once( ABSPATH . 'wp-settings.php' );" >> /var/www/$domain_name/html/wp-config.php

echo "Deleting readme.html"
rm /var/www/$domain_name/html/readme.html
echo "Deleting license.txt"
rm /var/www/$domain_name/html/license.txt
echo "Deleting wp-config-sample.php"
rm /var/www/$domain_name/html/wp-config-sample.php
rm latest.zip
sudo service nginx restart
echo " "
echo "open http://$domain_name"