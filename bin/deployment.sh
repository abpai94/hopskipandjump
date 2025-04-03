#!/bin/bash

function vpninrm() {
  LINODE=$(linode-cli linodes list --text --region ap-west | grep "\b${1}\b" | awk '{print $1}' | tail -n+2)
  linode-cli linodes delete $LINODE
}

function cloudflare_dns_entry() {
  IP_ADDRESS=$(linode-cli linodes list --text --region ${locations[$1]} --format 'ipv4' | tail -n+2);
  ID=$(curl https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records \
          -H "Content-Type: application/json" \
          -H "X-Auth-Email: $EMAIL_ADDRESS" \
          -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY" \
          -d '{
        "comment": "linode",
        "content": "'$IP_ADDRESS'",
        "name": "'vpn-$1.$DOMAIN'",
        "proxied": false,
        "ttl": 36000,
        "type": "A"
      }')
  ID=$(echo $ID | jq -r '.result.id')
  echo $ID > $PWD/data/$1.txt
}

function cloudflare_dns_delete() {
  ID=$(cat $PWD/data/$1.txt)
  curl https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$ID \
        -X DELETE \
        -H "X-Auth-Email: $EMAIL_ADDRESS" \
        -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY"
  rm $PWD/data/$1.txt
}

declare -A locations
locations+=( ["br"]=br-gru ["au"]=au-mel ["se"]=se-sto ["nl"]=nl-ams ["it"]=it-mil ["es"]=es-mad ["de"]=eu-central ["sg"]=ap-south ["jp"]=ap-northeast ["ca"]=ca-central ["us-east"]=us-east ["us-west"]=us-west ["us-cen"]=us-central ["gb"]=gb-lon ["fr"]=fr-par ["in"]=ap-west )

if [ "$1" == "in" ]; then
  if [ "$2" == "delete" ]; then
    vpninrm
    cloudflare_dns_delete $1
  fi
fi
if [ "$2" == "deploy" ]; then
  export FQDN=vpn-$1.$DOMAIN
  if [ ! -z "$IP_ADDRESS_SERVER" ]; then
    linode-cli linodes create --image linode/debian12 --private_ip false --region ${locations[$1]} --type g6-nanode-1 --label vpn-deployment-${locations[$1]} --root_pass $LINODE_VPS_PASSWORD --authorized_users $LINODE_AUTHORISED_USER --metadata.user_data=$(cat $PWD/bin/configuration_self_hosted.sh | envsubst | base64 -w0)
    export IP_ADDRESS_VPS=$(linode-cli linodes list --text --region ${locations[$1]} --format 'ipv4' | tail -n+2)
    cat $REVERSE_PROXY_SOURCE | envsubst > $REVERSE_PROXY_DESTINATION
  else
    export WIREGUARD_PASSWORD_HASH="PASSWORD_HASH=\'$(htpasswd -bnBC 12 "" $WIREGUARD_PASSWORD | cut -c2-)\'"
    linode-cli linodes create --image linode/debian12 --private_ip false --region ${locations[$1]} --type g6-nanode-1 --label vpn-deployment-${locations[$1]} --root_pass $LINODE_VPS_PASSWORD --authorized_users $LINODE_AUTHORISED_USER --metadata.user_data=$(cat $PWD/bin/configuration_full_deployment.sh | envsubst '$CLOUDFLARE_CERTBOT_API_TOKEN $FQDN $CLOUDFLARE_ZONE_ID $EMAIL_ADDRESS $CLOUDFLARE_GLOBAL_API_KEY $DOMAIN $PUSH_NOTIFICATION $WIREGUARD_PASSWORD' | base64 -w0)
    cloudflare_dns_entry $1
  fi
elif [ "$2" == "delete" ]; then
  if [ ! -z "$IP_ADDRESS_SERVER" ]; then
    LINODE=$(linode-cli linodes list --text --region ${locations[$1]} | grep "\b${1}\b" | awk '{print $1}')
    linode-cli linodes delete $LINODE
    rm $REVERSE_PROXY_DESTINATION
  else
    LINODE=$(linode-cli linodes list --text --region ${locations[$1]} | grep "\b${1}\b" | awk '{print $1}')
    linode-cli linodes delete $LINODE
    cloudflare_dns_delete $1
  fi
fi
if [ "$1" == "list" ]; then
  linode-cli linodes list
fi
