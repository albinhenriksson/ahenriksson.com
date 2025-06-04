+++
date = '2020-01-28T04:53:15Z'
draft = false
title = 'How to Enable Uploads of Files Larger Than 2mb to Your Wordpress Site Using Nginx'
+++

# How to enable uploads of files larger than 2MB to your WordPress-site (using NGINX)
*By Albin / 2020-01-28*

---

## I. Configure PHP-FPM

We start by editing the PHP-FPM configuration file `php.ini`, found here on Debian Buster (replace `7.3` with whatever version you’re running):

```bash
nano /etc/php/7.3/fpm/php.ini
```

Add the following lines at the very end of the file.
(Check out what this actually does on https://www.php.net/manual/en/ini.core.php)

```ini
upload_max_filesize = 100M
post_max_size = 100M
```

Reload the PHP-FPM service:

```bash
systemctl reload php7.3-fpm
```

---

## II. Configure NGINX

Now we configure the NGINX website configuration file on the host (note: not on the reverse proxy):

```bash
nano /etc/nginx/sites-available/website.com
```

It should look something like this:
(Find out what the added line does here: https://nginx.org/en/docs/http/ngx_http_core_module.html)

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

        client_max_body_size 100M; # Add this line!
    }
}
```

Check your configuration and reload NGINX:

```bash
nginx -t
systemctl reload nginx
```

---

And that should do it. Now I can finally upload those huge images SEO:s love.
