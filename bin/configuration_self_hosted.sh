#!/bin/bash

# Initial setup
touch /root/deployment.log

# Install Docker
curl https://get.docker.com | sh
echo "Installing docker" >> /root/deployment.log

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

    <Location />
      Require ip $IP_ADDRESS_SERVER
    </Location>

    ProxyPass / http://172.17.0.3:51821/
    ProxyPassReverse / http://172.17.0.3:51821/
</VirtualHost>" > /root/httpd/conf/httpd.conf

# Deploy HTTPD
docker run --detach --name httpd --network=bridge -p 80:80 -v /root/httpd/conf/:/usr/local/apache2/conf/ -v /root/httpd/logs/:/usr/local/apache2/logs/ --restart unless-stopped docker.io/httpd:2.4.63
echo "HTTPD deployment" >> /root/deployment.log

# Deploy wireguard
docker run --detach --name wireguard --network=bridge -e WG_HOST=$(curl ifconfig.me) -e WG_DEFAULT_DNS=1.1.1.1 -e WG_ALLOWED_IPS='0.0.0.0/0, ::/0' -e WG_DEFAULT_ADDRESS=10.252.1.x -e UI_TRAFFIC_STATS='true' -e UI_CHART_TYPE=1 -v /root/wireguard/:/etc/wireguard/ -p 51820:51820/udp --restart unless-stopped --cap-add NET_ADMIN --cap-add SYS_MODULE --sysctl 'net.ipv4.conf.all.src_valid_mark=1' --sysctl 'net.ipv4.ip_forward=1' ghcr.io/wg-easy/wg-easy:14
echo "Wireguard deployment" >> /root/deployment.log

# Notification
curl "$PUSH_NOTIFICATION_URL/message?token=$PUSH_NOTIFICATION_TOKEN" -F "title=$FQDN ready" -F "message=$(docker ps -a)"
echo "Pushing update notification" >> /root/deployment.log

# Update server
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y
echo "Server updated" >> /root/deployment.log
