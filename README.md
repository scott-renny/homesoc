# HomeSOC: Building a Real Security Operations Center From Scratch

> A live, ongoing build log of a self-hosted SOC stack — real hardware, real attacks, real incident documentation. No simulations, no cloud sandbox. Updated as the project progresses.

**Status:** 🟢 Live · Stack operational · Phase 08 of 11 complete
**Last updated:** June 13, 2026

---

## Why this exists

I'm a junior cybersecurity student working toward a SOC analyst role and CompTIA Security+ certification. Instead of only doing course labs, I bought a used laptop, wiped it, and built a real defensive security stack from the ground up — then exposed it to the actual internet to see what would happen.

Within the first hour of going live, the stack had already logged 693 security events, including reconnaissance scans and exploitation attempts mapped to MITRE ATT&CK techniques. Every incident below — including every error I hit along the way — is documented honestly. The mistakes are part of the portfolio, not hidden from it.

---

## Architecture

```
INTERNET
  │
  ▼
IPTABLES / CROWDSEC FIREWALL BOUNCER     ← network layer, banned IPs dropped here
  │
  ▼
MODSECURITY WAF (OWASP CRS)              ← application layer, blocks SQLi/XSS/RCE/CVEs
  │
  ▼
NGINX (Docker container)                 ← web server
  │
  ▼
WAZUH SIEM                               ← monitors every layer, custom detection rules
  │
  ▼
ALERT → ME
```

| Layer | Tool | Catches |
|---|---|---|
| Network | CrowdSec + iptables | Known malicious IPs, brute force, scanner bots |
| Application | ModSecurity + OWASP CRS | SQL injection, XSS, path traversal, RCE, CVE exploits |
| Web server | Nginx (Docker) | Access logs, request handling |
| Host | Wazuh agent | File integrity, process creation, auth events |
| SIEM | Wazuh dashboard | Centralised alerting, MITRE ATT&CK mapping, custom rules |

---

## Hardware

| Component | Spec |
|---|---|
| Machine | Dell Latitude E7250 |
| CPU | Intel Core i7-5600U |
| RAM | 8GB |
| OS | Ubuntu Server 22.04 LTS |
| Cost | $110 CAD |
| Known faults | Ethernet port (hardware fault, non-functional) · USB port 2 (error -71) |

Bought used, with two undisclosed hardware faults discovered during setup — both documented below as they directly shaped the build process.

---

## Build log

### ✅ Phase 01 — Hardware sourcing
Evaluated three used laptops (Lenovo Yoga 3 Pro, HP EliteBook 840 G2, Dell Latitude E7250) against CPU, RAM, and Linux compatibility. Selected the E7250 for best CPU performance at $110 CAD.

### ✅ Phase 02 — OS installation
Wiped Windows 11, installed Ubuntu Server 22.04 LTS. Chose Server over Desktop edition to reduce attack surface and match real production environments. Chose 22.04 over 24.04 for full Wazuh 4.7 compatibility and known driver stability with the laptop's Broadcom WiFi chip.

### ✅ Phase 03 — Base hardening
UFW firewall (default deny incoming), SSH lockdown (no root login, max 3 auth tries), lid-close suspend disabled so the server runs headless, automatic security updates enabled.

### ✅ Phase 04 — Docker
Docker Engine + Compose installed via the official repository method. Every service in the stack runs in an isolated container.

### ✅ Phase 05 — Web service
Nginx deployed as the public-facing attack surface, behind a DuckDNS subdomain.

### ✅ Phase 06 — Wazuh SIEM
Single-node Wazuh deployed via Docker. Agent installed on the host to monitor file integrity, auth logs, and system calls. **693 alerts captured in the first hour live**, including MITRE ATT&CK technique T1040 (Network Sniffing).

### ✅ Phase 07 — ModSecurity WAF
OWASP Core Rule Set deployed at Paranoia Level 1. Manually tested against three attack types:

| Attack | Payload | Result |
|---|---|---|
| Path traversal | `/../../../etc/passwd` | 404 (normalised, harmless) |
| SQL injection | `?id='OR+1=1` | **403 Forbidden** — blocked |
| Encoded path traversal | `%2e%2e%2f%2e%2e%2f/etc/passwd` | **400 Bad Request** — blocked |

### ✅ Phase 08 — CrowdSec
Crowd-sourced threat intelligence and automated IP banning. Hit three real incidents during install (see below) before landing on a firewall-bouncer architecture that's arguably stronger than the originally planned Nginx bouncer.

### ⏳ Phase 09 — Custom detection rules
Writing Wazuh rules to fix default alert levels that under-score real threats, and resolving a log queue overflow discovered in production.

### ⏳ Phase 10 — Active response automation
Wazuh → CrowdSec auto-ban pipeline, Discord webhook for real-time mobile alerts on high-severity events.

### ⏳ Phase 11 — Honeypot + portfolio finalisation
Cowrie SSH honeypot, per-CVE technical write-ups, final GitHub polish.

---

## Incident log

Every error encountered during the build, documented with root cause and fix. This is the part employers actually read.

<details>
<summary><strong>INC-001 — Broadcom WiFi adapter not detected</strong></summary>

**Symptom:** `ip link show` returned no wireless interface, only loopback and the (faulty) ethernet port.

**Root cause:** The Dell E7250 uses a Broadcom BCM4352 chip requiring the proprietary `bcmwl-kernel-source` driver, not included in a default Ubuntu Server install.

**Resolution:** See INC-004 — required internet access to install, which was complicated by two separate hardware faults below.
</details>

<details>
<summary><strong>INC-002 — Ethernet port hardware fault</strong></summary>

**Symptom:** `sudo ip link set eno1 up` produced kernel error: `e1000e 0000:00:19.0 eno1: Hardware Error`

**Root cause:** Physical fault on the Intel I218-LM ethernet controller — not disclosed by the seller, not detectable without testing under Linux.

**Resolution:** Accepted as a permanent hardware limitation. Used Android USB tethering as an alternative internet source.

**Lesson:** Always test ethernet under Linux before finalising a used laptop purchase — Windows drivers can mask faults that Linux exposes.
</details>

<details>
<summary><strong>INC-003 — USB port fault blocking phone tethering</strong></summary>

**Symptom:** `usb 2-2: device descriptor read/64, error -71` — phone tethering failing to enumerate on USB port 2.

**Root cause:** Physical fault on USB port 2 (error -71 = protocol error).

**Resolution:** Moved to USB port 3 (opposite side of laptop) — enumerated successfully, `usb0` adapter appeared.
</details>

<details>
<summary><strong>INC-004 — bcmwl-kernel-source install failing repeatedly</strong></summary>

**Symptom:** Multiple failed install attempts — typo in package name, connection dropping mid-download over phone tethering, then a cascading dependency chain (dkms, libc6-dev, gcc, make, fakeroot...) when attempting offline `.deb` installation via USB.

**Root cause:** Unstable tethering connection causing partial downloads, which corrupted the package manager state.

**Resolution:**
```bash
sudo apt --fix-broken install -y
sudo apt clean
sudo dpkg --configure -a
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
sudo apt install bcmwl-kernel-source -y
sudo modprobe wl
```
</details>

<details>
<summary><strong>INC-005 — Netplan YAML indentation error</strong></summary>

**Symptom:** `Invalid YAML: inconsistent indentation: dhcp4: true`

**Root cause:** YAML is whitespace-sensitive; mixed indentation from manual nano editing.

**Resolution:** Rewrote `/etc/netplan/00-installer-config.yaml` with strict 2-space indentation per nesting level.
</details>

<details>
<summary><strong>INC-006 — wpasupplicant missing, WiFi not associating</strong></summary>

**Symptom:** `wlp2s0` showed UP with an IPv6 link-local address but no IPv4 address. `dhclient` hung indefinitely.

**Root cause:** `wpasupplicant` is not installed by default on Ubuntu Server — required to authenticate with WPA2/WPA3 networks.

**Resolution:**
```bash
sudo apt install wpasupplicant -y
echo "127.0.1.1 homelabserver" | sudo tee -a /etc/hosts
sudo systemctl restart systemd-networkd
sudo netplan apply
```
**Result:** `inet 192.168.1.XXX/24` — WiFi connected, fully wireless from this point on.
</details>

<details>
<summary><strong>INC-007 — CrowdSec Nginx bouncer install failure</strong></summary>

**Symptom:** `crowdsec-nginx-bouncer depends on libnginx-mod-http-lua but it is not installable`

**Root cause:** The Nginx bouncer requires a system-level Nginx with Lua support. Nginx in this build runs inside Docker — no system Nginx exists to satisfy the dependency.

**Resolution:** Switched to `crowdsec-firewall-bouncer-iptables` — operates at the kernel level, arguably more effective since it drops banned IPs before they reach Nginx or ModSecurity at all.
</details>

<details>
<summary><strong>INC-008 — CrowdSec port conflict with WAF container</strong></summary>

**Symptom:** `FATAL local API server stopped: listening on 127.0.0.1:8080: bind: address already in use`

**Root cause:** CrowdSec's local API defaults to port 8080 — same port already bound by the ModSecurity WAF Docker container.

**Resolution:** Changed CrowdSec's API port to 8090 in `/etc/crowdsec/config.yaml` and `/etc/crowdsec/local_api_credentials.yaml`.
</details>

<details>
<summary><strong>INC-009 — CrowdSec CVE scenario names outdated</strong></summary>

**Symptom:** `can't find 'crowdsecurity/CVE-2021-41773' in scenarios, did you mean 'crowdsecurity/CVE-2022-44877'?`

**Root cause:** CrowdSec's Hub is a live, community-maintained repository — scenario names get superseded over time.

**Resolution:** Used CrowdSec's own suggested replacement names; confirmed both were already bundled in previously installed collections.

**Lesson:** Check `cscli scenarios list -a` for current names before referencing any specific CVE scenario.
</details>

---

## Lessons learned

- **Test hardware under Linux before buying.** Windows can mask faults — both hardware issues on this machine only surfaced once Linux touched the kernel drivers.
- **Avoid Broadcom WiFi chips if you can.** Intel or Realtek chips have native kernel support and need zero driver installation. This single decision caused the majority of the early troubleshooting.
- **wpasupplicant is not optional on Ubuntu Server.** It doesn't ship by default and WiFi will silently fail to associate without it.
- **YAML indentation is syntax, not style.** Netplan configs need exact, consistent spacing.
- **Phone tethering is a legitimate recovery tool** when ethernet and WiFi are both unavailable — but keep an eye on DNS and connection stability.
- **Container-based services break some default driver assumptions.** The CrowdSec Nginx bouncer assumed a system Nginx that didn't exist in a Dockerised setup — know your architecture before following a generic guide.

---

## What's next

Follow the in-progress phases at the top of this README, or check the [commit history](#) for incremental updates. New incident write-ups, screenshots, and MITRE ATT&CK mappings are added as the lab catches new real-world attack traffic.

---

## Contact

Built by Scott — junior cybersecurity student, Security+ candidate.
[LinkedIn](#) · [GitHub](#)
