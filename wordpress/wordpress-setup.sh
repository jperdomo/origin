#!/bin/bash

# Setup
sudo apt update
sudo apt upgrade -y
sudo apt install apache2 -y
sudo apt install mariadb-server mariadb-client -y
sudo apt install php libapache2-mod-php php-mysql php-cli php-cgi php-gd -y

# MariaDB
sudo mysql_secure_installation
sudo mysql -u root -p

## DB and User
CREATE DATABASE wordpress_db;
CREATE USER 'wordpress_user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wordpress_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Wordpress Setup
cd /var/www/html
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzvf latest.tar.gz
sudo mv wordpress/* .
sudo rm -rf wordpress latest.tar.gz
## Permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
## Config Wordpress
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/wordpress_db/" wp-config.php
sudo sed -i "s/username_here/wordpress_user/" wp-config.php
sudo sed -i "s/password_here/password/" wp-config.php
sudo sed -i "s/localhost/localhost/" wp-config.php

# Enable Apache Rewrite Module
sudo a2enmod rewrite
sudo systemctl restart apache2