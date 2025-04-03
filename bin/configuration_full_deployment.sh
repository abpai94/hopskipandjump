#!/bin/bash

# Initial setup
touch /root/deployment.log

# Install Docker
curl https://get.docker.com | sh
echo "Installing docker" >> /root/deployment.log

# Certbot Configurations
mkdir -p /root/certbot/cloudflare/
echo "dns_cloudflare_api_token = $CLOUDFLARE_CERTBOT_API_TOKEN" > /root/certbot/cloudflare/cloudflare.ini
echo "Certbot configuration" >> /root/deployment.log

# Deploy Certbot
docker run --detach --name certbot --network=bridge -v /root/certbot/cloudflare:/opt/cloudflare -v /root/certbot/letsencrypt:/etc/letsencrypt -v /root/certbot/letsencrypt/log:/var/log/letsencrypt --restart unless-stopped docker.io/certbot/dns-cloudflare:v3.2.0 certonly --non-interactive --dns-cloudflare --dns-cloudflare-credentials /opt/cloudflare/cloudflare.ini --email $EMAIL_ADDRESS --agree-tos -d $FQDN --expand --server https://acme-v02.api.letsencrypt.org/directory -v
echo "Certbot deployment" >> /root/deployment.log

# Wait for cert to generate
while [ ! -d "/root/certbot/letsencrypt/live" ]
do
  sleep 5
  echo "Waiting for certificate generation" >> /root/deployment.log
done

# Copy certificates
mkdir -p /root/httpd/certs/
cp /root/certbot/letsencrypt/live/$FQDN/* /root/httpd/certs/
echo "Copying certificates" >> /root/deployment.log

# Stopping certbot
docker stop certbot && docker rm -f certbot && docker system prune -a -f
echo "Stopping certbot" >> /root/deployment.log

# Generate wireguard password
docker pull ghcr.io/wg-easy/wg-easy:14
WIREGUARD_PASSWORD_HASH=$(docker run -it --rm ghcr.io/wg-easy/wg-easy wgpw $WIREGUARD_PASSWORD)

# Deploy wireguard
docker run --detach --name wireguard --network=bridge -e WG_HOST=$(curl ifconfig.me) -e WG_DEFAULT_DNS=1.1.1.1 -e WG_ALLOWED_IPS='0.0.0.0/0, ::/0' -e WG_DEFAULT_ADDRESS=10.252.1.x -e UI_TRAFFIC_STATS='true' -e UI_CHART_TYPE=1 -e $WIREGUARD_PASSWORD_HASH -v /root/wireguard/:/etc/wireguard/ -p 51820:51820/udp -p 51821:51821/tcp --restart unless-stopped --cap-add NET_ADMIN --cap-add SYS_MODULE --sysctl 'net.ipv4.conf.all.src_valid_mark=1' --sysctl 'net.ipv4.ip_forward=1' ghcr.io/wg-easy/wg-easy:14
echo "Wireguard deployment" >> /root/deployment.log

# HTTPD Configurations
mkdir -p /root/httpd/conf
echo "ServerRoot \"/usr/local/apache2\"

LoadModule mpm_event_module modules/mod_mpm_event.so
LoadModule authn_file_module modules/mod_authn_file.so
LoadModule authn_core_module modules/mod_authn_core.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule authz_groupfile_module modules/mod_authz_groupfile.so
LoadModule authz_user_module modules/mod_authz_user.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule access_compat_module modules/mod_access_compat.so
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule reqtimeout_module modules/mod_reqtimeout.so
LoadModule filter_module modules/mod_filter.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule env_module modules/mod_env.so
LoadModule headers_module modules/mod_headers.so
LoadModule setenvif_module modules/mod_setenvif.so
LoadModule version_module modules/mod_version.so
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so
LoadModule ssl_module modules/mod_ssl.so
LoadModule proxy_http2_module modules/mod_proxy_http2.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule status_module modules/mod_status.so
LoadModule autoindex_module modules/mod_autoindex.so
LoadModule dir_module modules/mod_dir.so
LoadModule alias_module modules/mod_alias.so
LoadModule rewrite_module modules/mod_rewrite.so

Listen 80
Listen 443

ErrorLog /usr/local/apache2/logs/error.log
CustomLog /usr/local/apache2/logs/access.log combined

LogFormat \""%h %l %u %t \\\"%r\\\" %\>s %b \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\"" combined
LogFormat \""%h %l %u %t \\\"%r\\\" %\>s %b\"" common

<VirtualHost *:80>
    ServerName $FQDN

    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule (.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName $FQDN

    ProxyRequests On
    ProxyPreserveHost On

    SSLEngine On
    SSLProxyEngine On

    SSLCertificateFile "/usr/local/apache2/certs/cert.pem"
    SSLCertificateKeyFile "/usr/local/apache2/certs/privkey.pem"
    SSLCertificateChainFile "/usr/local/apache2/certs/fullchain.pem"

    ProxyPass / http://172.17.0.2:51821/
    ProxyPassReverse / http://172.17.0.2:51821/
</VirtualHost>" > /root/httpd/conf/httpd.conf

# DNS entry
curl https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records \
        -H "Content-Type: application/json" \
        -H "X-Auth-Email: $EMAIL_ADDRESS" \
        -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY" \
        -d '{
      "comment": "linode",
      "content": "'"$(curl -4 ifconfig.me)"'",
      "name": "'$DOMAIN'",
      "proxied": false,
      "ttl": 36000,
      "type": "A"
    }'
echo "HTTPD configuration" >> /root/deployment.log

# Deploy HTTPD
docker run --detach --name httpd --network=bridge -p 80:80 -p 443:443 -v /root/httpd/certs/:/usr/local/apache2/certs/ -v /root/httpd/conf/:/usr/local/apache2/conf/ -v /root/httpd/logs/:/usr/local/apache2/logs/ --restart unless-stopped docker.io/httpd:2.4.63
echo "HTTPD deployment" >> /root/deployment.log

# Notification
curl "https://$PUSH_NOTIFICATION_URL/message?token=$PUSH_NOTIFICATION_TOKEN" -F "title=$FQDN ready" -F "message=$(docker ps -a)"
echo "Pushing update notification" >> /root/deployment.log

# Update server
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y
echo "Server updated" >> /root/deployment.log
