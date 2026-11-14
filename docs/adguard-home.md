# AdGuard Home

AdGuard Home is the LAN's recursive-forwarding DNS resolver, DNS-level
ad/tracker blocker, and source of local DNS rewrites. It replaces the
per-machine `/etc/hosts` entries formerly required for the homelab's internal
hostnames. Kubernetes service discovery remains with CoreDNS; AdGuard Home is
for LAN clients.

## Design

- **DNS VIP:** `192.168.0.53`, published by MetalLB on both UDP and TCP 53.
- **DNS listener:** the pod is host-networked (required for DHCP), so AdGuard
  listens on the node's `:5353`; the Service still publishes `:53` on the `.53`
  VIP and kube-proxy forwards to it. Node `:53` stays with `systemd-resolved`.
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

## Web UI (the dashboard)

`https://adguard.home.shatadru.in` is the operational view; no separate
exporter or dashboard stack is needed. Useful pages:

- **Dashboard** — query volume, blocked share, top clients, top domains, query
  types, upstream response times.
- **Query log** — per-client queries with the filter reason for each block.
- **Clients** — name known devices (phone, laptop, TV) so stats and rules read
  as names rather than bare IPs.
- **DHCP** (once enabled) — dynamic/static leases with hostname, IP, MAC, and
  expiry. This is the LAN client inventory.

Retention comes from the seed config: statistics 7 days, query log 30 days.
Raise `statistics.interval` / `querylog.interval` if you need a longer history.

## This router is locked down

The Virgin Media Hub 6 exposes **no setting to push a custom DNS server to DHCP
clients** (the same limitation as the Hub 3/4/5/5x). The only way to make AdGuard
Home the resolver for the LAN is to let **AdGuard Home serve DHCP as well** and
disable the Hub's DHCP server. That makes AdGuard Home the single source of DNS
**and** leasing, so this node is a dependency for every device on the LAN — plan
the IP pinning and rollback below before cutover.

Because the DHCP server must see broadcasts on the physical LAN interface, the
pod runs with `hostNetwork: true` and `NET_RAW`/`NET_ADMIN`. That is a
deliberate privilege increase; the patch is the `patches:` block in
`manifests/adguard-home/kustomization.yaml`.

## Network address plan

The hub's DHCP pool is `192.168.0.100-192.168.0.255`. The MetalLB pool is
`192.168.0.10-192.168.0.80`. These do not overlap, so the AdGuard VIP
(`192.168.0.53`) and the Traefik VIP (`192.168.0.11`) can never collide with a
DHCP client. The `192.168.0.81-192.168.0.99` band is intentionally unallocated
as a buffer between the two pools.

| Range | Purpose |
| --- | --- |
| `192.168.0.10-80` | MetalLB load-balancer VIPs (AdGuard `.53`, Traefik `.11`) |
| `192.168.0.81-99` | Buffer — unallocated |
| `192.168.0.100-254` | Client pool served by AdGuard Home's DHCP (keeps the Hub's current allocation) |

## Before deployment

1. Reserve `192.168.0.53` inside the MetalLB pool (it is currently unassigned).
2. Create the namespace and configuration Secret before Argo CD syncs the
   Application. Do not add the generated file or password hash to Git.
3. **Set `dns.port: 5353` in the Secret *and* in the live config before
   deploying the host-network overlay.** Node port 53 belongs to
   `systemd-resolved`; AdGuard cannot bind it from the host network namespace.
   The Service still publishes `.53:53` and forwards to 5353.
4. **Pin the k3s node's address (`.163`) before the cutover.** The node leases
   `.163` from the Hub's DHCP pool. Once AdGuard takes over DHCP you must not
   lose the node. Set a static IP on the node's `enp3s0` interface, or add a
   DHCP reservation on the Hub *before* disabling its DHCP server.
5. **Confirm the Deco mesh is in bridge/AP mode.** If it routes instead, wifi
   clients are behind a second DHCP server and never see AdGuard's DHCP or DNS;
   only wired clients would be covered.
6. Ideally disable IPv6 Router Advertisement on the Hub so clients do not take
   the Hub's IPv6 DNS and bypass AdGuard (verify with a DNS-leak test).
7. The node also has `wlp6s0` (`.111`) on this subnet. Once the Hub's DHCP is
   off it will not renew; disable that NetworkManager connection or give it a
   static address so it does not log lease failures.

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
  # Host-network pod: node :53 belongs to systemd-resolved. The DNS Service
  # publishes .53:53 and forwards to this port.
  port: 5353
  upstream_dns:
    - https://dns.quad9.net/dns-query
    - https://cloudflare-dns.com/dns-query
  bootstrap_dns:
    - 9.9.9.9
    - 1.1.1.1
  cache_size: 16777216
filtering:
  protection_enabled: true
  filtering_enabled: true
  blocking_mode: default
  # DNS rewrites live under `filtering:`. A top-level `rewrites:` key is
  # silently ignored by AdGuard Home, which leaves local names unresolved.
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

The heredoc above is **unquoted** (`<<EOF`) so the shell expands
`${password_hash}`. A quoted heredoc (`<<'EOF'`) stores the literal text
`${password_hash}` and every admin login then fails with 403. Verify before
moving on:

```bash
kubectl -n adguard-home get secret adguard-home-config \
  -o jsonpath='{.data.AdGuardHome\.yaml}' | base64 -d \
  | grep -F '${password_hash}' && echo 'ERROR: password hash was not expanded'
```

The `copy-config` init container seeds the configuration **only when
`/opt/adguardhome/conf/AdGuardHome.yaml` does not exist**. To re-seed after
fixing the Secret, delete that file (or the `-conf` PVC) and restart the pod;
query logs and statistics live on the separate `-work` PVC.

## Router and client cutover

After Argo CD reports the Application healthy, confirm the service owns the
expected VIP:

```bash
kubectl -n adguard-home get service
dig @192.168.0.53 argocd.home.shatadru.in
dig @192.168.0.53 example.com
```

### 1. Enable the AdGuard Home DHCP server (do this first)

In the AdGuard Home UI (Settings ▸ DHCP settings), enable the built-in DHCP
server with:

| Setting | Value |
| --- | --- |
| DHCP server | On |
| Interface | `enp3s0` (the node's LAN NIC, visible in the host netns) |
| DHCPv4 range start | `192.168.0.100` |
| DHCPv4 range end | `192.168.0.254` |
| Netmask | `255.255.255.0` |
| Gateway address | `192.168.0.1` |
| DNS servers | no UI field — add DHCP option `6 ips 192.168.0.53` (below) |
| Lease duration | e.g. 24h |

AdGuard advertises itself as the client DNS server by default. Because the pod
is host-networked, "itself" is the node's `192.168.0.163`, where nothing listens
on port 53. Add a custom option so clients get the VIP: in **DHCP options**, add
`6 ips 192.168.0.53`.

Keep the pool at `192.168.0.100-192.168.0.254` — it mirrors the Hub's current
range and never touches the MetalLB pool (`192.168.0.10-80`).

### 2. Disable the Hub's DHCP server (last step)

Do **not** add a second DHCP or DNS server as a fallback: clients may choose it
over AdGuard and bypass the ad blocker and local rewrites. Once the Hub's DHCP
is off, renew clients' leases or reconnect them to the LAN so they pick up
AdGuard as their resolver.

> Only run this step after confirming DNS works (step 1 tests) and the k3s node
> IP is pinned. If anything breaks, re-enable the Hub's DHCP server to roll back.

For first access before the router change, use:

```bash
kubectl -n adguard-home port-forward service/adguard-home-adguard-home-web 8080:80
```

Then open `http://127.0.0.1:8080`. Once local DNS is active, use
`https://adguard.home.shatadru.in` (the existing self-signed certificate must
be trusted by the client).

### 3. Verify

```bash
dig @192.168.0.53 argocd.home.shatadru.in   # local rewrite, answers .11
dig @192.168.0.53 example.com                # resolves via upstream
```

From a client, confirm its resolver is `192.168.0.53` (check DHCP-assigned DNS,
and run a DNS-leak test to ensure the Virgin Media/IPv6 resolver does not
appear). AdGuard Home's query log shows which clients are actually using it.

The AdGuard UI is the client dashboard: **DHCP** lists the lease (hostname, IP,
MAC, expiry) and **Dashboard → Top clients** shows the device once it queries.
Name devices under **Clients** so the stats stay readable.

## Operations and recovery

This is a single replica on a single-node cluster. If the node or AdGuard Home
is unavailable, clients using it as their only DHCP/DNS server cannot obtain a
lease or resolve new names. The fallback is to re-enable the Hub's DHCP server,
which also hands out the Hub's own resolver. Do not run a permanent
public-resolver fallback if filtering and local rewrites must remain enforced.

The Secret seeds configuration only on first start. Manage filters, rewrites,
DHCP, and client settings through the AdGuard UI afterwards, or replace the
Secret and recreate the configuration PVC when a complete declarative reset is
intended.

Rollback has two parts: re-enable the Hub's DHCP server, and — if you also
remove the host-network patch — set the config's `dns.port` back to `53` so the
Service's `targetPort` matches the listener again.
