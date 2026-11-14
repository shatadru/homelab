# AdGuard Home

AdGuard Home is the LAN's recursive-forwarding DNS resolver, DNS-level
ad/tracker blocker, and source of local DNS rewrites. It replaces the
per-machine `/etc/hosts` entries formerly required for the homelab's internal
hostnames. Kubernetes service discovery remains with CoreDNS; AdGuard Home is
for LAN clients.

## Design

- **DNS VIP:** `192.168.0.53`, published by MetalLB on both UDP and TCP 53.
- **Web UI:** `https://adguard.home.shatadru.in`, through the existing Traefik
  VIP (`192.168.0.11`).
- **Configuration:** `adguard-home-config` Secret in the `adguard-home`
  namespace. It is intentionally not stored in Git because it includes the
  bcrypt admin-password verifier.
- **Persistence:** separate local-path PVCs for configuration and working
  data (query logs, statistics, and filter lists).

AdGuard Home provides all required features: LAN DNS serving, custom DNS
rewrites, DNS-level blocking/filter lists, encrypted upstream DNS, query logs,
and per-client controls. Pi-hole is not needed for this use case.

## Before deployment

1. Reserve `192.168.0.53` outside the router's DHCP range. It is in MetalLB's
   configured `192.168.0.10-192.168.0.80` pool and is currently unassigned.
2. Create the namespace and configuration Secret before Argo CD syncs the
   Application. Do not add the generated file or password hash to Git.

Generate a bcrypt hash with `htpasswd` and create a private configuration file:

```bash
read -rsp 'AdGuard admin password: ' password; echo
password_hash="$(htpasswd -bnBC 12 '' "$password" | tr -d ':\n')"
unset password

cat > /tmp/AdGuardHome.yaml <<EOF
http:
  address: 0.0.0.0:80
  session_ttl: 720h
users:
  - name: admin
    password: "${password_hash}"
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  upstream_dns:
    - https://dns.quad9.net/dns-query
    - https://cloudflare-dns.com/dns-query
  bootstrap_dns:
    - 9.9.9.9
    - 1.1.1.1
  protection_enabled: true
  filtering_enabled: true
  blocking_mode: default
  cache_size: 16777216
filtering:
  protection_enabled: true
  filtering_enabled: true
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
querylog:
  enabled: true
  interval: 720h
statistics:
  enabled: true
  interval: 168h
rewrites:
  - domain: adguard.home.shatadru.in
    answer: 192.168.0.11
  - domain: argocd.home.shatadru.in
    answer: 192.168.0.11
  - domain: alertmanager.home.shatadru.in
    answer: 192.168.0.11
  - domain: cloud.home.shatadru.in
    answer: 192.168.0.11
  - domain: collabora.home.shatadru.in
    answer: 192.168.0.11
  - domain: companion.home.shatadru.in
    answer: 192.168.0.11
  - domain: gatus.home.shatadru.in
    answer: 192.168.0.11
  - domain: grafana.home.shatadru.in
    answer: 192.168.0.11
  - domain: homarr.home.shatadru.in
    answer: 192.168.0.11
  - domain: id.home.shatadru.in
    answer: 192.168.0.11
  - domain: immich.home.shatadru.in
    answer: 192.168.0.11
  - domain: paperless.home.shatadru.in
    answer: 192.168.0.11
  - domain: prometheus.home.shatadru.in
    answer: 192.168.0.11
schema_version: 29
EOF

kubectl create namespace adguard-home
kubectl -n adguard-home create secret generic adguard-home-config \
  --from-file=AdGuardHome.yaml=/tmp/AdGuardHome.yaml
rm -f /tmp/AdGuardHome.yaml
unset password_hash
```

## Router and client cutover

After Argo CD reports the Application healthy, confirm the service owns the
expected VIP:

```bash
kubectl -n adguard-home get service
dig @192.168.0.53 argocd.home.shatadru.in
dig @192.168.0.53 example.com
```

Set the router DHCP DNS server to **`192.168.0.53`**. Renew clients' DHCP
leases or reconnect them to the LAN. Do not publish a public resolver as a
second DHCP DNS server: clients may choose it instead, bypassing the ad blocker
and local rewrites.

For first access before the router change, use:

```bash
kubectl -n adguard-home port-forward service/adguard-home-web 8080:80
```

Then open `http://127.0.0.1:8080`. Once local DNS is active, use
`https://adguard.home.shatadru.in` (the existing self-signed certificate must
be trusted by the client).

## Operations and recovery

This is a single replica on a single-node cluster. If the node or AdGuard Home
is unavailable, clients using only this DNS server cannot resolve new names.
For an outage, temporarily restore the router's previous DNS configuration;
do not add a permanent public-resolver fallback if filtering and rewrites must
remain enforced.

The Secret seeds configuration only on first start. Manage filters, rewrites,
and client settings through the AdGuard UI afterwards, or replace the Secret
and recreate the configuration PVC when a complete declarative reset is
intended.
