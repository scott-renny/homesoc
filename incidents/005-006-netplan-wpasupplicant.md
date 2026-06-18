# INC-005 & INC-006 — Netplan Configuration Failures

**Date:** 2026-06-13
**Severity:** Medium
**Status:** Resolved
**Component(s) affected:** Netplan, systemd-networkd, wpasupplicant

---

## INC-005 — Netplan YAML indentation error

### Summary
After the Broadcom driver was installed and loaded, configuring WiFi credentials via Netplan failed due to a YAML syntax error.

### Symptom
```
user@homelabserver:~$ sudo netplan apply
/etc/netplan/00-installer-config.yaml:6:9: Invalid YAML: inconsistent indentation:
  dhcp4: true
```

### Diagnosis
Manually inspected the config file with `sudo cat /etc/netplan/00-installer-config.yaml`. Visual inspection showed indentation that appeared correct at a glance but was inconsistent at the whitespace-character level (mix of 2-space and 4-space indents introduced while editing in nano).

### Root Cause
YAML is a whitespace-significant format — indentation level is part of the syntax, not cosmetic. Manually typing nested YAML in a terminal editor is error-prone because inconsistent indentation isn't visually obvious.

### Resolution
Deleted the file contents entirely (`Ctrl+K` repeatedly in nano) and retyped the configuration with deliberate, counted indentation — exactly 2 spaces per nesting level:

```yaml
network:
  version: 2
  renderer: networkd
  wifis:
    wlp2s0:
      dhcp4: true
      optional: true
      access-points:
        "network-name":
          password: "network-password"
```

### Lessons Learned
When editing YAML manually, count indentation levels explicitly rather than relying on visual alignment. Consider using `yamllint` for future config files to catch this class of error before applying.

---

## INC-006 — wpasupplicant missing, WiFi adapter UP but not associating

### Summary
After fixing the YAML syntax, `netplan apply` succeeded with no errors, but the WiFi adapter still could not obtain an IPv4 address from the router.

### Symptom
```
user@homelabserver:~$ ip addr show wlp2s0
4: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    link/ether 18:4f:32:f3:54:19 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::1a4f:32ff:fef3:5419/64 scope link
```
Adapter shows `UP` and `LOWER_UP` (physical link active) but only has an IPv6 link-local address — no IPv4 `inet` line. Running `sudo dhclient wlp2s0` manually hung indefinitely with no response.

### Diagnosis
The adapter being UP with LOWER_UP confirmed the WiFi driver and radio hardware were both functioning correctly. The absence of a DHCP-assigned IPv4 address despite a seemingly correct Netplan config pointed to an authentication/association failure rather than a DHCP failure — the adapter likely never successfully joined the network at the 802.11 protocol level.

### Root Cause
`wpasupplicant` was not installed. This package handles WPA2/WPA3 authentication handshakes — without it, `networkd` cannot actually associate with a secured access point, even though the radio itself is functional and a config file is present. Ubuntu Server does not install `wpasupplicant` by default; Ubuntu Desktop does.

### Resolution
```bash
sudo apt install wpasupplicant -y
```

A secondary, unrelated issue surfaced during this fix — a hostname resolution warning:
```
sudo: unable to resolve host homelabserver: Name or service not known
```
Fixed by adding a local hosts entry:
```bash
echo "127.0.1.1 homelabserver" | sudo tee -a /etc/hosts
```

Restarted networking and reapplied configuration:
```bash
sudo systemctl restart systemd-networkd
sudo netplan apply
sleep 15
ip addr show wlp2s0
```

**Result:**
```
inet 192.168.1.XXX/24 metric 600 brd 192.168.1.255 scope global dynamic wlp2s0
```
WiFi fully connected. Confirmed with `ping -c 4 google.com`.

### MITRE ATT&CK / Security+ Mapping
- Security+ Domain: D3 — Security Architecture (wireless authentication protocols, WPA2/WPA3)

### Lessons Learned
An interface showing `UP` does not necessarily mean it has successfully associated with a network — always check for an assigned IPv4 address as the real confirmation of connectivity, not just interface state flags. `wpasupplicant` should be considered a required package, not optional, for any Ubuntu Server build that needs WiFi.
