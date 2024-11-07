# rccremote-docker
Docker-compose setup for rccremote 

To execute Robot Framework tests with Robotmk, the test client must be connected to the Internet if the underlying Python/Node.js environment is built with RCC. However, for security reasons, test clients are often completely isolated from the Internet.

RCCRemote operates unencrypted, meaning clients cannot verify the connection, nor is the data transmission encrypted.

In this setup, RCCRemote is operated behind a reverse proxy (nginx). Two operating modes are available:

- Self-signed certificate (not recommended): Encrypted, but no authentication.
- Certificate signed by a root CA: Encrypted and authenticated.

---

## Create certificates


### Step 5: Add the PEM content to the profile settings

- Locate `rcc-profile-cabundle.yaml`, which already contains an example certificate.  
- Remove all lines after `ca-bundle: |` and add the file content of `rootCA.pem`.
- Save the file.

IMportant: watch the indentation with 2 spaces, example: 

```
ca-bundle: |
  -----BEGIN CERTIFICATE-----
  MIIFuDCCA6CgAwIBAgIULSNdzH238Z4lY3XPT7KZloIt4DkwDQYJKoZIhvcNAQEL
  BQAwYjELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVN0YXRlMQ0wCwYDVQQHDARDaXR5
  MRAwDgYDVQQKDAdZb3VyT3JnMREwDwYDVQQLDAhZb3VyVW5pdDEPMA0GA1UEAwwG
```


---

## Start the containers

``` 
docker compose up -d
```

This starts

- `c1` (rccremote = server)
- `c2` (rcc)
- `rccremote` (= nginx securing c1)
  - Test: https://localhost in the browser should now open an insecure connection, the certificate should be for _rccremote_

---

## nginx 


---

## c2

### Test connection to nginx

Test with openssl whether the SSL connection from c2 to nginx works. 

Test without the root certificate: 

    openssl s_client -connect rccremote:443
    ...
    ...
    Verify return code: 21 (unable to verify the first certificate)
    Extended master secret: no
    Max Early Data: 0
    ---
    read R BLOCK

test with Root certificate: 

    openssl s_client -connect rccremote:443 -CAfile /etc/certs/rootCA.crt
    Verify return code: 0 (ok)     #  <------------------------------
    Extended master secret: no
    Max Early Data: 0
    ---
    read R BLOCK

### Set RCCREMOTE


    export RCC_REMOTE_ORIGIN=https://rccremote:443


### import environment with import 

    cd /data/minimal7
    rcc ht vars

Verify that rcc denies to fetch from rccremote:

```
####  Progress: 03/14  v13.7.1     0.000s  Fill hololib from RCC_REMOTE_ORIGIN.
Error [http.Do]: Get "https://rccremote:443/parts/a466d176c7dc6696v12.linux_amd64": x509: certificate signed by unknown authority
Warning: Failed to pull "a466d176c7dc6696v12.linux_amd64" from "https://rccremote:443", reason: Problem with parts request, status=9002, body=
```

Now import the RCC profile which contains the CABundle: 

    rcc config import -f /data/rcc-profile-cabundle.yaml

Check whether profile is ready to activate: 

    rcc config switch

Activate profile: 

    rcc config switch -p rccremote-cabundle

Verify changed settings `config-active-profile` and `config-ssl-verify`: 

    rcc config diag

Fetching from rccremote should work now: 

    rcc ht vars

## Addendum



Show crt details: 

    openssl x509 -in /etc/nginx/server.crt -text -noout

Switch to default profile: 

    rcc config switch --noprofile

