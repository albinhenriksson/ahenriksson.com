+++
date = '2020-01-26T04:47:04Z'
draft = false
title = 'Make Debian Lxc Containers More Comfortable to Use'
+++

# Make Debian/Ubuntu LXC containers more comfortable to use
*By Albin / 2020-01-26*

---

I’ve been playing around with Proxmox and LXC containers lately and this is something I do with every container I create for it to be more user-friendly.

---

## 1. Enable colors in the terminal

```bash
echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\] '" >> ~/.bashrc
```

---

## 2. Enable tab completion

```bash
echo "source /etc/profile.d/bash_completion.sh" >> ~/.bashrc
```

---

## 3. Fix locale problems

```bash
echo "LC_ALL=en_US.UTF-8" >> /etc/environment
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen en_US.UTF-8
```

---

## 4. Set up automatic package downloads with cron-apt

Install `cron-apt`:

```bash
apt install cron-apt
```

Configure it to always email the results:

```bash
echo 'MAILON="always"' >> /etc/cron-apt/config
```

---

Now your LXC containers should be a lot nicer to work in!
