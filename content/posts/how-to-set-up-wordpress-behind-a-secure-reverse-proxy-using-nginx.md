+++
date = '2020-01-27T04:51:53Z'
draft = false
title = 'How to Set Up Wordpress Behind a Secure Reverse Proxy Using Nginx'
+++

# How to set up WordPress behind a secure reverse proxy using NGINX
*By Albin / 2020-01-27*

---

After getting your SSL certificate and enabling HTTPS redirection in NGINX, WordPress will not work due to mixed content (HTTP and HTTPS) – you won’t be able to login.

To fix this:

---

## 1. Edit `wp-config.php`

Add this at the very start of your `wp-config.php`:

```php
define('FORCE_SSL_ADMIN', true);
if ($_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')
 $_SERVER['HTTPS']='on';
```

Then, at the end of the file, add the following (replacing `website.com` with your actual domain):

```php
define('WP_HOME','https://website.com');
define('WP_SITEURL','https://website.com');
```

---

## 2. Edit your NGINX reverse proxy config

In the site’s `location` block on your **reverse proxy**, add:

```nginx
proxy_set_header X-Forwarded-Proto https;
```

---

Now it should be working!

You should probably also install the plugin **Really Simple SSL** for its mixed content fixer.
