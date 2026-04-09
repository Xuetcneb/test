#!/bin/bash

set -e

# Variables à adapter
DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASS="secret"
SITE_DIR="/var/www/html/wordpress"

echo "=== Mise à jour du système ==="
apt update && apt upgrade -y

echo "=== Installation Apache, MariaDB, PHP ==="
apt install -y apache2 mariadb-server php php-mysql libapache2-mod-php php-cli php-curl php-gd php-xml php-mbstring unzip wget

echo "=== Activation des services ==="
systemctl enable apache2
systemctl enable mariadb
systemctl start apache2
systemctl start mariadb

echo "=== Configuration MariaDB ==="
mysql -u root <<EOF
CREATE DATABASE if not exists ${DB_NAME};
CREATE USER if not exists '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "=== Téléchargement de WordPress ==="
wget https://wordpress.org/latest.zip
unzip latest.zip

echo "=== Déploiement ==="
rm -rf ${SITE_DIR}
mv wordpress ${SITE_DIR}

echo "=== Permissions ==="
chown -R www-data:www-data ${SITE_DIR}
chmod -R 755 ${SITE_DIR}

echo "=== Configuration wp-config.php ==="
cp ${SITE_DIR}/wp-config-sample.php ${SITE_DIR}/wp-config.php

sed -i "s/database_name_here/${DB_NAME}/" ${SITE_DIR}/wp-config.php
sed -i "s/username_here/${DB_USER}/" ${SITE_DIR}/wp-config.php
sed -i "s/password_here/${DB_PASS}/" ${SITE_DIR}/wp-config.php

echo "=== Activation mod_rewrite ==="
a2enmod rewrite
systemctl restart apache2

echo "=== Configuration Apache ==="
cat <<EOL > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot ${SITE_DIR}

    <Directory ${SITE_DIR}>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

a2dissite 000-default.conf
a2ensite wordpress.conf
systemctl reload apache2

echo "=== Installation terminée ==="
IP="192.168.1.121"
echo "Accède à WordPress ici : http://$IP"
