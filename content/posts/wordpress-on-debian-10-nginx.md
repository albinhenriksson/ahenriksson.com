+++
date = '2020-01-26T04:43:25Z'
draft = false
title = 'Wordpress on Debian 10 Nginx'
+++

# How to install WordPress on Debian 10 with NGINX (LEMP)
*By Albin / 2020-01-26*

---

This is mostly a guide for myself so I can remember how to install a WordPress-site – but if somebody else finds it helpful that’s great.

---

## 1. Install dependencies

```bash
apt install nginx mariadb-server php
```

Install and configure the firewall:

```bash
apt install ufw
ufw enable
ufw allow 80/tcp
ufw allow 443/tcp
```

---

## 2. Secure MySQL and create DB/user

```bash
mysql_secure_installation

mysql -u root -p
```

Inside MySQL:

```sql
CREATE DATABASE website_db;
CREATE USER website_user@localhost IDENTIFIED BY 'super-secure-password';
GRANT ALL PRIVILEGES ON website_db.* TO website_user@localhost;
FLUSH PRIVILEGES;
QUIT;
```

---

## 3. Configure NGINX

Create your NGINX config:

```bash
nano /etc/nginx/sites-available/website.com
```

Paste this (edit the domain):

```nginx
server {
    listen 80;
    root /var/www/html/website.com;
    server_name website.com;

    location / {
        index       index.php index.html;
        try_files   $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.3-fpm.sock;
        fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

Enable the site and reload:

```bash
unlink /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/website.com /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

Optional: Hide server details:

```nginx
# Edit /etc/nginx/nginx.conf
server_tokens off;
```

---

## 4. Install required PHP packages

```bash
apt install php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip php7.3-opcache php7.3-mysql php7.3-cli php7.3-fpm
```

---

## 5. Install WordPress

```bash
wget https://wordpress.org/latest.tar.gz -P /tmp
tar xzf /tmp/latest.tar.gz --strip-components=1 -C /var/www/html/website.com
cp /var/www/html/website.com/wp-config-sample.php /var/www/html/website.com/wp-config.php
chown -R www-data:www-data /var/www/html/website.com
```

---

## 6. Configure wp-config.php

Generate your salts:

```bash
curl -s https://api.wordpress.org/secret-key/1.1/salt/
```

Then open config:

```bash
nano /var/www/html/website.com/wp-config.php
```

Edit the database settings:

```php
define( 'DB_NAME', 'website_db' );
define( 'DB_USER', 'website_user' );
define( 'DB_PASSWORD', 'super-secure-password' );
```

Replace the salt/key section with the values you generated.

---

## Done!

Now visit your site to finish the WordPress installation:
Example: `http://192.168.1.104`

If you found something wrong with the tutorial, don’t hesitate to write me an e-mail.
