# Architecture Deep Dive

## 1. Security Hardening (Rootless)
In traditional Docker, the daemon runs as `root`. In this project:
- The `sysadmin` user is mapped to a range of UIDs via `/etc/subuid`.
```bash
  [danny@rhel ~]$ cat /etc/subuid
danny:100000:65536
sysadmin:165536:65536
```
- Inside the container, `UID 0` (root) is mapped to `UID 1001` (sysadmin) on the host.
- **Benefit**: Even if an attacker escapes the container, they only have the permissions of a standard user.

## 2. Declarative Management (Quadlet)
Quadlet is a generator for Systemd. Instead of writing complex service files, we use a simple `.container` file.
- **How it works**: At boot, `podman-systemd-generator` scans `~/.config/containers/systemd/` and creates transient service units in `/run/user/$(id -u)/systemd/generator/`.
```bash
[sysadmin@rhel systemd]$ podman ps
CONTAINER ID  IMAGE                           COMMAND               CREATED        STATUS        PORTS                 NAMES
952fbe32e19c  docker.io/library/nginx:latest  nginx -g daemon o...  4 minutes ago  Up 4 minutes  0.0.0.0:8080->80/tcp  app-server

[sysadmin@rhel systemd]$ systemctl --user daemon-reload
[sysadmin@rhel systemd]$ systemctl --user reset-failed app-server.service
[sysadmin@rhel systemd]$ systemctl --user start app-server.service

[sysadmin@rhel systemd]$ systemctl --user status app-server.service
● app-server.service - Hardened Nginx Rootless Container
     Loaded: loaded (/home/sysadmin/.config/containers/systemd/app-server.conta>
     Active: active (running) since Thu 2026-04-02 15:30:56 +08; 2min 24s ago
   Main PID: 4491 (conmon)
      Tasks: 5 (limit: 10292)
     Memory: 197.6M (peak: 276.8M)
        CPU: 7.629s
     CGroup: /user.slice/user-1001.slice/user@1001.service/app.slice/app-server>
             ├─libpod-payload-952fbe32e19c61d8b38904f6b101831a36d99a5cebb6bcde3>
             │ ├─4493 "nginx: master process nginx -g daemon off;"
             │ ├─4517 "nginx: worker process"
             │ └─4518 "nginx: worker process"
             └─runtime
               ├─4489 /usr/bin/pasta --config-net -t 8080-8080:80-80 --dns-forw>
               └─4491 /usr/bin/conmon --api-version 1 -c 952fbe32e19c61d8b38904>
```

## 3. Network Stack: PASTA
RHEL 9 uses PASTA by default for rootless networking.
- **PASTA** (Pack A Subnet To Adapter) provides better performance than `slirp4netns`.
```bash
├─4489 /usr/bin/pasta --config-net -t 8080-8080:80-80 --dns-forw>
```
- **Note**: PASTA bridges the host's actual IP to the container, making it a "near-native" networking experience for rootless users.

## 4. Automated Operations
By adding `AutoUpdate=image` to the Quadlet file and enabling `podman-auto-update.timer`, the system periodically:
1. Checks the registry for new image digests.
2. Pulls the new image if available.
3. Automatically restarts the Systemd service to apply the update.

Test
```bash
[sysadmin@rhel systemd]$ curl http://192.168.112.139:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional 
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
