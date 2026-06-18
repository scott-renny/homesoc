# INC-003 & INC-004 — USB Port Fault + Driver Install Failures

**Date:** 2026-06-12
**Severity:** High
**Status:** Resolved
**Component(s) affected:** USB port 2, bcmwl-kernel-source, apt package manager

---

## INC-003 — USB port 2 hardware fault blocking phone tethering

### Summary
With ethernet unavailable (INC-002), Android USB tethering was attempted as an alternative internet source. The first USB port tried also failed.

### Symptom
```
[ 4250.872717] usb usb2-port2: unable to enumerate USB device
[ 4248.829593] usb 2-2: device descriptor read/64, error -71
```
Repeated enumeration failures. No `usb0` network interface appeared despite the phone showing "USB tethering active."

### Diagnosis
Error -71 corresponds to `EPROTO` (protocol error) at the USB controller level — this occurs when the physical port cannot establish reliable communication with the connected device, independent of the device itself being functional (confirmed by testing the same phone/cable combination on a different machine, which worked normally).

### Root Cause
Physical hardware fault on USB port 2 specifically — not a driver, cable, or phone configuration issue.

### Resolution
Moved the same USB cable to USB port 3 (opposite side of the laptop chassis). Enumeration succeeded immediately:
```
6: usb0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN ...
```

### Lessons Learned
When a peripheral fails to enumerate, test a different physical port before assuming a driver or software issue — especially on used hardware with unknown history.

---

## INC-004 — bcmwl-kernel-source repeated install failures

### Summary
Multiple attempts to install the Broadcom WiFi driver failed for different reasons in sequence: a typo, an unstable tethered connection causing partial downloads, and a resulting broken package state with a deep dependency chain.

### Symptom (chronological)

**Attempt 1 — typo:**
```
E: Unable to locate package bcmwl-kernal-source
```

**Attempt 2 — connection drop mid-download:**
```
Failed to fetch http://archive.ubuntu.com/.../bcmwl-kernel-source_6.30...deb
Temporary failure resolving 'archive.ubuntu.com'
E: Unable to fetch some archives, maybe run apt-get update or try with --fix-missing?
```

**Attempt 3 — offline .deb install, missing dependencies:**
```
dpkg: dependency problems prevent configuration of bcmwl-kernel-source:
 bcmwl-kernel-source depends on dkms; however:
  Package dkms is not installed.
 bcmwl-kernel-source depends on linux-libc-dev; however:
  Package linux-libc-dev is not installed.
```

**Attempt 4 — dependency chain cascading further:**
```
dkms : Depends: gcc | c-compiler; however: Package gcc is not installed.
build-essential : Depends: gcc (>= 4:10.2); however: not going to be installed
```

### Diagnosis
The root issue was an unstable internet connection (Android USB tethering dropping mid-transfer), which left `apt`'s package state inconsistent. Each subsequent install attempt surfaced a new layer of unmet dependencies because the package manager had partially-applied changes from earlier failed attempts.

### Root Cause
1. Initial typo (`kernal` vs `kernel`) — trivial, immediately visible
2. Underlying cause: phone tethering connection instability causing truncated downloads
3. Compounding cause: broken package state from repeated failed installs masking the actual fix needed

### Resolution
Cleaned the broken package state before any further install attempts:
```bash
sudo apt --fix-broken install -y
sudo apt clean
sudo dpkg --configure -a
```

Fixed DNS resolution issues that were contributing to tethering instability:
```bash
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
```

Retried the install on a stable connection:
```bash
sudo apt install bcmwl-kernel-source -y
sudo modprobe wl
```

Result: `wlp2s0` appeared in `ip link show` — driver successfully loaded.

### MITRE ATT&CK / Security+ Mapping
- Security+ Domain: D3 — Security Architecture (driver/dependency management)

### Lessons Learned
- Always verify a connection is stable before running long package downloads — interrupted `apt` operations leave the system in an inconsistent state that compounds with each retry
- `sudo dpkg --configure -a` and `sudo apt --fix-broken install -y` are the standard first response to "broken packages" errors — run these before attempting anything else
- A single typo can waste significant troubleshooting time if not checked first; always re-read exact error text character by character before assuming a deeper problem
