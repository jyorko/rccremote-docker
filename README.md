# rccremote-docker

Docker-compose setup with SSL for [rccremote](https://sema4.ai/docs/automation/rcc/overview).

## Background

In order to built RCC environments with **rcc**, the host must be connected to the Internet in order to download the installation sources for Python/Node.js/etc.  
However, for security reasons, test clients are often completely isolated from the Internet.

**RCCRemote** solves this problem by serving the blueprints of these environments (aka "_hololib_") for **RCC** clients which can fetch the blueprints from there.  
This centralized approach does not only save network traffic and computing resources, but also is a significant performance gain, because when the clients ask for environments, rccremote only relays the missing files, not the whole environment.

By default, **rccremote** operates unencrypted, meaning **rcc** cannot verify the connection, nor is the data transmission encrypted.  

This setup provides a way to run RCCRemote behind a reverse proxy (nginx) which TLS encryption and server authentication. 


## Quick Start 

### Option 1: Using own certificates 

Copy your certificate files into `/certs`:

- Server certificate: 
  - `server.crt` (X.509 compatible)
  - `server.key` 
- Root certificate: 
  - `rootCA.pem` (if the server certificate is signed by a CA - recommended) - Note: the server certificate must contain the SAN (X509v3 Subject Alternative Name) attribute.

### Option 2: Self-signed certificate

If you want the **nginx** container to create a self-signed certificate, leave the `certs` folder empty.  
Nginx will then create a self-signed certificate on the very first start. 

### Setting the server name

Set the **server name** used in the certificate to the env variable `SERVER_NAME`: 

- `export SERVER_NAME=rccremote.local`
- OR 
- edit the variable `SERVER_NAME` in `.env`

### Starting the containers

```
docker compose up -d
```

This will spin up 2 containers: 

- **rccremote** 
- **nginx**

## Usage

### Startup phase of rccremote

While starting, the **rccremote** container locates all `robot.yaml` files in `/robots` and builds the hololibs for each `robot.yaml` which has a `conda.yaml` on its side.  
All created hololibs in `/opt/robocorp` are saved persistently in a mounted volume.  
After all hololibs have been built, the **rccremote** process gets started. 

### Adding more environment definitions

`/robots` in the project directory is a host mounted folder in **rccremote** container.  
Copy the robot folder which contains `robot.yaml` and `conda.yaml` into `/robots` and restart the container:

`docker compose restart`

**rccremote** will then build the new hololib (existing hololibs won't be rebuilt).

## rcc: usage with rccremote

In `docker-compose.yaml` you can find the container **rcc**, commented by default.  
You do not need this container in production, but it's useful for testing **rcc** in combination with **rccremote**.

To use that container, follow these steps:

### Start the rcc client container

Uncomment the **rcc** container definition and start it: 

`docker compose up -d rcc`

Open a shell inside the **rcc** container: 

`docker exec -it rcc bash`


### RCC client profile configuration

On startup, the **rcc** container auto-configures the profile SSL-setting depending on whether the folder `certs` contains a root certificate (`rootCA.pem`) or not: 

If `rootCA.pem` is 
  
- **not present** => Profile **no-sslverify** with setting `verify-ssl: false`
- **present** => Profile **cabundle** with `verify-ssl: true` and the PEM content included into the profile YAML configuration

You can verify the active **rcc** profile with `rcc config switch`:

```
root@0ca74438d77f:/# rcc config switch
Available profiles:
- ssl-noverify: disabled SSL verification

Currently active profile is: ssl-noverify    # <----
OK.
```

### Testing rcc fetching the hololib from rccremote

Change into a robot folder below of `/robots` (this is the same host mounted `/robots` folder as on **rccremote**) where `robot.yaml` and `conda.yaml` files are. 

Verify that `RCC_REMOTE_ORIGIN` is set to the nginx server, port 443: 

```
root@0ca74438d77f:/robots/rf7# echo $RCC_REMOTE_ORIGIN
https://rccremote.local:443
```

Execute `rcc holotree vars`. **rcc** should be able to download the hololib from the server: verify that

- **rcc** prints _"Fill hololib from RCC_REMOTE_ORIGIN"_ in step 03
- the log of **rccremote** (`docker logs rccremote`) shows lines like these: 

```
08.155430.331 [D] Query of catalog "a466d176c7dc6696v12.linux_amd64" took 0.000s
08.155430.345 [D] query handler: "a466d176c7dc6696v12.linux_amd64" -> true
08.155430.347 [D] Using existing cache file "/tmp/rccremote/a3d9fb43c5e0589e6b57b1e5608d60e23a3ce2acc256a41d0f2090d62230ae47_parts.zip" [size: 65.3M]
08.155430.401 [D] Delta of catalog "a466d176c7dc6696v12.linux_amd64" took 0.056s
```

## Debugging 

### Connection test from rcc to nginx

Test without the root certificate: 

    openssl s_client -connect rccremote.local:443
    ...
    ...
    Verify return code: 21 (unable to verify the first certificate)
    Extended master secret: no
    Max Early Data: 0
    ---
    read R BLOCK

Test with Root certificate: 

    openssl s_client -connect rccremote:443 -CAfile /etc/certs/rootCA.crt
    Verify return code: 0 (ok)     #  <------------------------------
    Extended master secret: no
    Max Early Data: 0
    ---
    read R BLOCK

### rcc settings

    rcc config diag

### rest

Show crt details: 

    openssl x509 -in /etc/nginx/server.crt -text -noout

Switch to default profile: 

    rcc config switch --noprofile

