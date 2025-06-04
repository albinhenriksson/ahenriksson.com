+++
date = '2020-02-24T05:00:03Z'
draft = false
title = 'The Complete Guide to Installing Nextcloud on Debian 10'
+++

# The complete guide to installing Nextcloud on Debian 10
*By Albin / 2020-02-24*

Today we’re installing the free and open source cloud platform **Nextcloud** on a machine running Debian 10. Nextcloud is, in a nutshell, a secure self-hosted replacement for Dropbox, Google Docs and Google Calendar. You should own your data – not the big companies.

The guide somewhat resembles the WordPress how-to – as we did then we set up a database, a web server and a website written in PHP that is meant to sit behind a reverse proxy giving it a secure connection to the internet.

> Just a note: there are more simple ways of doing this, either by using Docker or Snaps – but you won’t get the same ability to tweak, configure or add third party apps. And most importantly, you won’t learn how it works.

---

## I. The Database

We start off with installing a relational database management system:

```bash
apt -y install mariadb-server mariadb-client
```

Then we set it up – use a long secure password for the root user:

```bash
mysql_secure_installation
```

Now it’s time to create the database and database user Nextcloud will be using:

```sql
mysql -u root -p

CREATE USER 'nextcloud_user'@'localhost' IDENTIFIED BY 'super-secure-password';
CREATE DATABASE nextcloud_db;
GRANT ALL PRIVILEGES ON nextcloud_db.* TO 'nextcloud_user'@'localhost';
FLUSH PRIVILEGES;
QUIT;
```

---

## II. The Web Server

Since Nextcloud is written in PHP, we install it (and some extensions):

```bash
apt -y install php php-{cli,xml,zip,curl,gd,cgi,mysql,mbstring,imagick,intl}
```

Then install Apache:

```bash
apt -y install apache2 libapache2-mod-php
```

Adjust PHP settings:

```bash
nano /etc/php/7.3/apache2/php.ini
```

Set the following values:

```ini
date.timezone = Europe/Stockholm
memory_limit = 512M
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
```

Download the latest version of Nextcloud:

```bash
wget https://download.nextcloud.com/server/releases/latest-18.zip
unzip latest-18.zip
```

Move files into web root and set permissions:

```bash
rm /var/www/html/index.html

cd nextcloud/
mv * /var/www/html/
mv .htaccess /var/www/html/
mv .user.ini /var/www/html/

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
```

Create a data folder outside the web root:

```bash
mkdir /nextcloud-data
chown -R www-data:www-data /nextcloud-data
```

Create the Apache config:

```bash
nano /etc/apache2/sites-available/nextcloud.conf
```

Paste the following:

```apacheconf
<VirtualHost *:80>
	ServerAdmin replaceme@email.com
	DocumentRoot /var/www/html
	ServerName replaceme.com

	<Directory /var/www/html/>
		Options +FollowSymlinks
		AllowOverride All
		Require all granted
		<IfModule mod_dav.c>
			Dav off
		</IfModule>
		SetEnv HOME /var/www/html
		SetEnv HTTP_HOME /var/www/html
	</Directory>

	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

Activate the config and enable modules:

```bash
unlink /etc/apache2/sites-enabled/000-default.conf
ln -s /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-enabled/

a2enmod rewrite
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime

systemctl restart apache2
```

Edit the Nextcloud config for trusted domains:

```bash
nano /var/www/html/config/config.php
```

```php
'trusted_domains' =>
array (
  0 => '192.168.1.50',
  1 => 'example.com',
  2 => 'www.example.com',
),
```

---

## III. Additional Fixes

Check for errors in:

```
http://your-ip-address/settings/admin/overview
```

Fix missing DB indexes:

```bash
cd /var/www/html/
apt install sudo
sudo -u www-data php occ db:add-missing-indices
```

Fix column type conversion:

```bash
sudo -u www-data php occ db:convert-filecache-bigint
```

Enable pretty URLs:

```bash
nano /var/www/html/config/config.php
```

```php
'overwrite.cli.url' => 'http://example.com',
'overwritehost'     => 'example.com',
'htaccess.RewriteBase' => '/',
```

Update Nextcloud with new settings:

```bash
cd /var/www/html/
sudo -u www-data php occ maintenance:update:htaccess
```

Set up a cron job for background tasks:

```bash
crontab -u www-data -e
```

```cron
*/5  *  *  *  * php -f /var/www/html/cron.php
```

Install and configure APCu cache:

```bash
apt install php-apcu
systemctl restart apache2
```

Enable APCu in config:

```bash
nano /var/www/html/config/config.php
```

```php
'memcache.local' => '\OC\Memcache\APCu',
```

Enable APCu CLI in PHP:

```bash
nano /etc/php/7.3/apache2/php.ini
```

```ini
apc.enable_cli=1
```

---

And that is it! You are now the owner of your very own cloud. 🙂

P.S. if you find something wrong with the guide please tell me so I can fix it!
