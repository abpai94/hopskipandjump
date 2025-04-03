# Hopskipandjump

Repository that should easily enable the deployment and deletion of VPNs on a VPS (linode).

## Why Linode?

Linode provides a cheap VPS service on their shared CPU tier along with an easy to use `linode-cli` tool to create, inspect and delete VPSs. They also provide the ability to push scripts or `cloud-init` to configure the VPS after provisioning and booting up. The best part is the cost where their [shared-cpu](https://www.linode.com/pricing/) where their cheapest offering (which we will use) costs $0.0075 per hour, rounding upto $0.01 per hour or £0.01 or €0.01 per hour for the UK and EU customers respectively. There's a max cap that means if you forget to delete the VPS it will not charge more than this limit. Most people rarely use their VPNs for more than a few hours per day and maybe averaging 10s of hours per month at most. This cuts costs down by 90+% without having to rely on a subscription service on months/years where you may never need a VPN.

## Pre-requisites

Required:
- Linode account
- Linode API key
- Domain on Cloudflare
- Cloudflare Global API key
- Cloudflare Certbot API key

Optional:
- Gotify push notification
  - URL
  - API key

Option 1:
- Full remote VPS deployment

Option 2:
- Self-hosted server with VPS deployment

## Deployment styles

### Full deployment

Some of you want a simple process to deploy, connect, use and delete VPNs at your convenience. This is where the full deployment works best. It will deploy three containers certbot to generate the certificates to enable HTTPS connections to the wireguard web interface, HTTPD reverse proxy container to expose wireguard and finally the wireguard container itself where you can create, manage and delete clients.

### Self-hosted with VPS deployment

Being a self hoster myself it felt a bit execessive to deploy a VPN remotely and generate certificates each time. As some of us already have a reverse proxy configured with an authentication proxy, this deployment style will piggy back on the server to proxy to the web interface of the remotely deployed VPN to create, manage and delete the clients on wireguard. This does require a wildcard certificate to be generated to cover the additional subdomain that will be created when the vpn is deployed.

## Configuration

| Configurations                 | Descriptions                                                                                   | Required for Option 1 | Required for Option 2 | Optional              |
| ------------------------------ | ---------------------------------------------------------------------------------------------- | --------------------- | --------------------- | --------------------- |
| `DOMAIN`                       | Domain that will be used to create the sub-domains per country for the wireguard web interface | [x]                   | [x]                   |                       |
| `EMAIL_ADDRESS`                | Email address for certbot to send emails when certificates expire                              | [x]                   | [x]                   |                       |
| `LINODE_CLI_TOKEN`             | Linode cli token key with linode edit privileges enabled                                       | [x]                   | [x]                   |                       |
| `LINODE_AUTHORISED_USER`       | SSH key username on linode authorised to SSH to the VPS                                        | [x]                   | [x]                   |                       |
| `LINODE_VPS_PASSWORD`          | Password to SSH into the Linode VPS                                                            | [x]                   | [x]                   |                       |
| `CLOUDFLARE_ZONE_ID`           | Cloudflare DNS Zone ID                                                                         | [x]                   | [x]                   |                       |
| `CLOUDFLARE_GLOBAL_API_KEY`    | Cloudflare Global API key to POST and DELETE sub-domains and VPS IP addresses                  | [x]                   | [x]                   |                       |
| `PUSH_NOTIFICATION_URL`        | Gotify push notification URL                                                                   |                       |                       | [x]                   |
| `PUSH_NOTIFICATION_TOKEN`      | Gotify push notification token key                                                             |                       |                       | [x]                   |
| `IP_ADDRESS_SERVER`            | External IP address of your self hosting server                                                |                       | [x]                   |                       |
| `REVERSE_PROXY_SOURCE`         | Reverse proxy source configuration file                                                        |                       | [x]                   |                       |
| `REVERSE_PROXY_DESTINATION`    | Reverse proxy destination folder                                                               |                       | [x]                   |                       |
| `CLOUDFLARE_CERTBOT_API_TOKEN` | Cloudflare API key with privileges to create certificates                                      | [x]                   |                       |                       |
| `WIREGUARD_PASSWORD`           | Password for the wireguard web interface                                                       | [x]                   |                       |                       |

## CLI

```
docker exec -it hopskipandjump vpn gb deploy
docker exec -it hopskipandjump vpn gb delete
docker exec -it hopskipandjump vpn list
```

## Countries available (Availablity subject to linode)

```
br => Sao Paulo, Brazil
au => Melbourne, Australia
se => Stolkholm, Sweden
nl => Amsterdam, Netherlands
it => Milan, Italy
es => Madrid, Spain
de => Frankfurt, Germany
sg => Singapore
jp => Tokyo, Japan
ca => Toronto, Canada
us-east => Newark, New Jersey, US
us-west => Fremont, California, US
us-cen => Dallas, Texas, US
gb => London, UK
fr => Paris, France
in => Mumbai, India
```

## Contribution

Feel free to fork this repository and contribute features.

```
docker buildx build -t hopskipandjump .
docker compose up -d
```

## Credit

This project wouldn't be possible without [wg-easy](https://github.com/wg-easy/wg-easy/tree/production). This is a project I have relied upon for many years to provide an easy to use wireguard docker container for my home server. Many thanks to [WeeJeWel](https://github.com/sponsors/WeeJeWel) and [kaaax0815](https://github.com/sponsors/kaaax0815) for the hard work of maintaining the project. Please sponsor their project if you decide to use this repository to make VPNs more easily accessible for more people.
