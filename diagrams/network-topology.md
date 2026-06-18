# Network Topology — HomeSOC Build

All IP addresses below are placeholders. Replace `192.168.1.X` with your own
local subnet and `YOUR_PUBLIC_IP` with your own public IP if you reproduce
this diagram for your own build — never publish your real addresses publicly.

---

## Full traffic flow — inbound request

```
                              INTERNET
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   HOME ROUTER / NAT     │
                    │   Port forward 80/443   │
                    │   to server local IP    │
                    └────────────┬────────────┘
                                 │
                                 ▼
        ┌─────────────────────────────────────────────┐
        │         DELL LATITUDE E7250 (homelabserver)   │
        │         Ubuntu Server 22.04 LTS               │
        │         Local IP: 192.168.1.X (WiFi)           │
        │         Ethernet: disabled (hardware fault)    │
        └─────────────────────┬─────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   IPTABLES (kernel)     │
                    │   CrowdSec Firewall     │
                    │   Bouncer enforces here │
                    │                         │
                    │   Banned IPs dropped    │
                    │   before anything below │
                    │   ever sees the packet  │
                    └────────────┬────────────┘
                                 │ (clean traffic only)
                                 ▼
        ┌─────────────────────────────────────────────┐
        │     DOCKER NETWORK: waf-net (bridge)          │
        │                                                │
        │   ┌──────────────────────────────────────┐    │
        │   │  ModSecurity WAF (OWASP CRS)          │    │
        │   │  owasp/modsecurity-crs:nginx-alpine   │    │
        │   │  Listens: 8080 (HTTP) / 8443 (HTTPS)  │    │
        │   │  Paranoia Level: 1                    │    │
        │   │                                        │    │
        │   │  Blocks: SQLi, XSS, path traversal,   │    │
        │   │  RCE attempts, known CVE exploit       │    │
        │   │  patterns                              │    │
        │   └────────────────┬─────────────────────┘    │
        │                    │ (passes clean requests)    │
        │                    ▼                             │
        │   ┌──────────────────────────────────────┐    │
        │   │  Nginx (nginx:alpine)                 │    │
        │   │  Internal port 80                     │    │
        │   │  Serves static web content            │    │
        │   └──────────────────────────────────────┘    │
        └─────────────────────────────────────────────┘
                                 │
                                 │ (logs + events)
                                 ▼
        ┌─────────────────────────────────────────────┐
        │   DOCKER NETWORK: wazuh-stack (bridge)        │
        │                                                │
        │   ┌──────────────────────────────────────┐    │
        │   │  Wazuh Manager + Indexer + Dashboard  │    │
        │   │  Single-node deployment                │    │
        │   │  Dashboard: https://192.168.1.X        │    │
        │   └────────────────┬─────────────────────┘    │
        │                    ▲                             │
        │                    │ agent reports               │
        │   ┌────────────────┴─────────────────────┐    │
        │   │  Wazuh Agent (on host)                │    │
        │   │  Monitors: auth logs, file integrity, │    │
        │   │  process creation, syscalls            │    │
        │   └──────────────────────────────────────┘    │
        └─────────────────────────────────────────────┘
                                 │
                                 ▼
                         ┌───────────────┐
                         │  ALERT → ME    │
                         │  (dashboard /  │
                         │   future:      │
                         │   Discord bot) │
                         └───────────────┘
```

---

## Network interface map

This reflects the actual interfaces present on the running server
(IP addresses redacted — see `ip addr show` output format below):

```
INTERFACE          PURPOSE                          NETWORK
─────────────────────────────────────────────────────────────────
lo                 Loopback                         127.0.0.1/8
eno1               Ethernet (hardware fault — DOWN)  n/a
wlp2s0             WiFi — primary connection         192.168.1.X/24
docker0            Default Docker bridge             172.17.0.1/16
br-xxxxxxxxxxxx    Wazuh stack bridge network        172.18.0.1/16
br-xxxxxxxxxxxx    WAF/Nginx stack bridge network    172.19.0.1/16
veth*              Virtual ethernet pairs            (one per container)
```

---

## Why two separate Docker networks

The Wazuh stack and the WAF/Nginx stack run on **separate bridge networks**
rather than one shared network. This provides container-level isolation —
web-facing containers cannot directly reach SIEM containers except through
explicitly defined routes (in this case, log shipping via the Wazuh agent
on the host, not direct container-to-container traffic).

This is defence-in-depth applied at the container layer: even if the
web-facing Nginx/WAF containers were somehow compromised, they have no
direct network path to the Wazuh manager or indexer.

---

## Port reference

| Port | Service | Exposed to |
|---|---|---|
| 22 | SSH | LAN only (not internet-facing) |
| 80 | ModSecurity WAF → Nginx | Internet (via router port forward) |
| 443 | ModSecurity WAF → Nginx | Internet (via router port forward) |
| 8090 | CrowdSec local API | Localhost only (127.0.0.1) |
| 443 (internal) | Wazuh Dashboard | LAN only |

Note: CrowdSec's local API was moved from its default port 8080 to 8090
specifically because port 8080 was already bound by the WAF container's
host port mapping — see `configs/crowdsec-config-notes.yaml` for the full
explanation and `incidents/` for the troubleshooting process.
