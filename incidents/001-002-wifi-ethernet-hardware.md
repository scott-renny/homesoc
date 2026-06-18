# INC-001 & INC-002 — WiFi Driver Missing + Ethernet Hardware Fault

**Date:** 2026-06-12
**Severity:** High (blocked all further setup)
**Status:** Resolved (WiFi) / Accepted limitation (Ethernet)
**Component(s) affected:** Network connectivity, Broadcom BCM4352, Intel I218-LM

---

## INC-001 — Broadcom WiFi adapter not detected

### Summary
After installing Ubuntu Server 22.04, no WiFi adapter appeared on the system despite the laptop having a physical WiFi card.

### Symptom
```
user@homelabserver:~$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> ...
2: eno1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN ...
```
Only loopback and the ethernet interface were present. No wireless interface listed.

### Diagnosis
Ran `sudo lshw -C network` to query all network hardware regardless of driver state:

```
*-network DISABLED
    description: Ethernet interface
    product: Ethernet Connection (3) I218-LM
    vendor: Intel Corporation
*-network
    description: Network controller
    product: BCM4352 802.11ac Wireless Network Adapter
    vendor: Broadcom Inc. and subsidiaries
    configuration: driver=bcma-pci-bridge
```

The WiFi card was physically detected by the kernel, but only a stub driver (`bcma-pci-bridge`) was loaded — not the full functional driver.

### Root Cause
Broadcom BCM4352 requires the proprietary `bcmwl-kernel-source` package, which is in Ubuntu's restricted repository and is **not included by default** on Ubuntu Server. Ubuntu Desktop typically bundles this; Server does not.

### Resolution
Required internet access to download the driver package — see INC-004 for the full installation saga, which was complicated by INC-002 and INC-003 below.

### MITRE ATT&CK / Security+ Mapping
- Security+ Domain: D3 — Security Architecture (hardware/driver dependency awareness)

### Lessons Learned
Before committing to Ubuntu Server on unfamiliar hardware, check the WiFi chipset against Ubuntu's hardware compatibility list. Intel and Realtek chips have native kernel support; Broadcom does not.

---

## INC-002 — Ethernet port hardware fault

### Summary
The laptop's physical ethernet port failed to bring up a link, blocking the most obvious path to installing the WiFi driver.

### Symptom
```
user@homelabserver:~$ sudo ip link set eno1 up
[ 3842.201362] e1000e 0000:00:19.0 eno1: Hardware Error
```

### Diagnosis
Confirmed the cable and router port were both functional by testing with another device. Re-seated the ethernet cable, retried — same hardware error persisted at the kernel level, ruling out a cabling issue.

### Root Cause
Physical fault on the Intel I218-LM ethernet controller itself. This is a hardware-level failure, not a software or driver issue — confirmed by the `e1000e` kernel module reporting a hardware error directly, rather than a link negotiation failure.

This fault was not disclosed by the seller and would not have been detectable without testing under Linux — Windows network stack handles certain hardware faults differently and may not surface the same error.

### Resolution
No software fix exists for a physical hardware fault. Accepted as a permanent limitation of this specific unit. Used Android USB tethering as an alternative path to internet access (see INC-003).

### MITRE ATT&CK / Security+ Mapping
- Security+ Domain: D3 — Security Architecture (resilience and compensating controls when primary hardware fails)

### Lessons Learned
Always test the ethernet port under Linux — not just Windows — before finalising a used laptop purchase. Added to the project's hardware buying checklist for future reference.
