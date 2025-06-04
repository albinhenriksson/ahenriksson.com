+++
date = '2020-02-24T04:58:50Z'
draft = false
title = 'Fixing Apt Update and Upgrade on Proxmox Without Subscription'
+++

# Fixing apt update/upgrade on Proxmox (without subscription)
*By Albin / 2020-02-24 – 2021-08-23*

This is an extremely trivial guide – but when installing Proxmox for the first time I would have needed a guide like it.

As default, Proxmox is set to update against their paid enterprise repositories – but without a subscription you have no access to them. So what you have to do is remove the enterprise repository and add the free equivalent.

---

First, delete the following file:

```bash
rm /etc/apt/sources.list.d/pve-enterprise.list
```

Then edit your sources list:

```bash
nano /etc/apt/sources.list
```

Add or ensure it looks like this:

```sources.list
deb http://ftp.se.debian.org/debian buster main contrib
deb http://ftp.se.debian.org/debian buster-updates main contrib

# Add the line below!
deb http://download.proxmox.com/debian/pve buster pve-no-subscription

# security updates
deb http://security.debian.org buster/updates main contrib
```

---

You should now be able to update your server and begin your virtualization adventure.
