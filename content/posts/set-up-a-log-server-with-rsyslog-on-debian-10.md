+++
date = '2020-01-30T04:57:41Z'
draft = false
title = 'Set Up a Log Server With Rsyslog on Debian 10'
+++

# Set up a log server with Rsyslog on Debian 10
*By Albin / 2020-01-30 – 2021-08-23*

It is very handy to store all your logs in one place, especially in the event of a crash on one of your machines – you can then do the detective work on why it crashed using another computer (that works). It is of course also easier to search for errors across your machines and similar tasks.

This is why you need a log server – and today we’re installing one on a Debian 10 LXC container (but it could just as well be installed on a virtual or real machine).

---

## I. Server side

Check that Rsyslog is running (it should be installed by default):

```bash
systemctl status rsyslog
```

If it isn’t running, install, start, and enable it:

```bash
apt install rsyslog
systemctl start rsyslog
systemctl enable rsyslog
```

Make a backup and edit the config:

```bash
cp /etc/rsyslog.conf /etc/rsyslog.conf.old
nano /etc/rsyslog.conf
```

Enable UDP (faster but less reliable) and TCP (slower but more reliable) by uncommenting the following lines:

```rsyslog
# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")
```

Define a log template and storage format:

```rsyslog
# Everything should be logged in "/var/log/host/progname.log".
$template RemoteLogs,"/var/log/%HOSTNAME%/%PROGRAMNAME%.log"
# It should be formatted as: '[facility-level].[severity-level] ?RemoteLogs'.
*.* ?RemoteLogs
# Stop.
& ~
```

Restart Rsyslog and set up firewall rules:

```bash
systemctl restart rsyslog

apt install ufw
ufw enable
ufw allow 514/tcp
ufw allow 514/udp
```

Done with the server! Now let’s configure the clients.

---

## II. Client side

Repeat these steps on each computer/server that should send logs to the log server.

Edit the config:

```bash
nano /etc/rsyslog.conf
```

Assuming the log server has IP `192.168.1.51`, add:

```rsyslog
# Log everything on our server.
*.* @@192.168.1.51:514
```

Finally, restart Rsyslog:

```bash
systemctl restart rsyslog
```

Done!
