#!/bin/sh

# Substitute environment variables in nginx.conf
envsubst '$NGINX_PORT' </etc/nginx/nginx.conf.template >/etc/nginx/nginx.conf

# Start nginx
nginx -g 'daemon off;'
