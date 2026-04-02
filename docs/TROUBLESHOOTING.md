# Troubleshooting & Lessons Learned

## Issue 1: Failed to connect to bus (D-Bus Session)
**Symptoms**: 
```bash
[sysadmin@rhel user]$ systemctl --user daemon-reload
Failed to connect to bus: No medium found
```
**Root Cause**: D-Bus session environment variables are not automatically set when using `su -`.
**Solution**:
```bash
[sysadmin@rhel user]$ export XDG_RUNTIME_DIR=/run/user/$(id -u)
[sysadmin@rhel user]$ echo "export XDG_RUNTIME_DIR=/run/user/$(id -u)" >> ~/.bashrc
```
## Issue 2: Quadlet File Location
**Symptoms**: Service does not exist after daemon-reload
```bash
[sysadmin@rhel user]$ systemctl --user enable --now app-server.service
Failed to enable unit: Unit file app-server.service does not exist.
```
**Root Cause**: Quadlet files MUST be in ~/.config/containers/systemd/. They are NOT standard systemd unit files.

**Solution**:
```bash
[sysadmin@rhel user]$ mkdir -p ~/.config/containers/systemd/
[sysadmin@rhel user]$ mv ~/.config/systemd/user/app-server.container ~/.config/containers/systemd/
[sysadmin@rhel user]$ systemctl --user daemon-reload
```

## Issue 3: Unit is transient or generated
**Symptoms**: systemctl --user enable fails.
```bash
[sysadmin@rhel user]$ systemctl --user enable --now app-server.service
Failed to enable unit: Unit /run/user/1001/systemd/generator/app-server.service is transient or generated.
```
**Root Cause**: Quadlet services are automatically "enabled" by the generator. You only need to start them

**Solution**:
```bash
[sysadmin@rhel systemd]$ systemctl --user start app-server.service
```

## Issue 4: Start-Limit-Hit (S2I Image Conflict)
**Symptoms**: Status Failed
```bash
[sysadmin@rhel user]$ systemctl --user status app-server.service
× app-server.service - Hardened Nginx Rootless Container
     Loaded: loaded (/home/sysadmin/.config/containers/systemd/app-server.conta>
     Active: failed (Result: start-limit-hit) since Thu 2026-04-02 15:19:45 +08>
   Duration: 82ms
    Process: 3828 ExecStart=/usr/bin/podman run --name app-server --replace --r>
    Process: 3848 ExecStop=/usr/bin/podman rm -v -f -i app-server (code=exited,>
    Process: 3856 ExecStopPost=/usr/bin/podman rm -v -f -i app-server (code=exi>
   Main PID: 3828 (code=exited, status=0/SUCCESS)
        CPU: 236ms

[sysadmin@rhel ~]$ podman logs app-server
This is a S2I  rhel base image.
To use it in OpenShift, run:
  oc new-app nginx:1.22~https://github.com/sclorg/nginx-container.git --context-dir=1.22/test/test-app/
You can then run the resulting image via:
  docker run -p 8080:8080 nginx-sample-app
Alternatively, to run the image directly using podman or docker, or how to use it as a parent image in a Dockerfile, see documentation at
  https://github.com/sclorg/nginx-container/blob/master/1.22/README.md.
```
**Root Cause**: Using a Source-to-Image (S2I) UBI image without providing source code causes the Nginx process to exit immediately after printing help text.
**Solution**:Use a standard Nginx image or provide an entrypoint command.
Image Before:
```bash
Image=registry.access.redhat.com/ubi9/nginx-122:latest
```
Image After:
```bash
# Fixed in app-server.container
Image=docker.io/library/nginx:latest
```

## Issue 5: Connection Refused via Localhost
**Symptoms**:Container is running, but curl localhost:8080 fails.
```bash
[sysadmin@rhel systemd]$ curl http://localhost:8080
curl: (7) Failed to connect to localhost port 8080: Connection refused
```
**Root Cause**: PASTA driver's loopback isolation in rootless mode.
**Solution**:Access via host's actual IP address or configure PASTA mapping.
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
