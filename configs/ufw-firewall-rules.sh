# UFW Firewall Rules — Base System Hardening
#
# Applied during Phase 03, before any services were exposed to the
# internet. Default-deny posture: nothing gets in unless explicitly
# allowed.
#
# Apply these in order:

# Default policies — set BEFORE enabling, to avoid locking yourself out
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH — required for remote management, do this before enabling UFW
# or you will lose your SSH session permanently
sudo ufw allow ssh

# Web traffic — added once the Nginx/WAF stack was deployed (Phase 05)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable the firewall
sudo ufw enable

# Verify active rules
sudo ufw status verbose

# ── EXPECTED OUTPUT ──
# Status: active
# Default: deny (incoming), allow (outgoing), disabled (routed)
#
# To                         Action      From
# --                         ------      ----
# 22/tcp (SSH)                ALLOW       Anywhere
# 80/tcp                      ALLOW       Anywhere
# 443/tcp                     ALLOW       Anywhere

# ── WARNING ──
# Always allow SSH (port 22) BEFORE running 'ufw enable' if you are
# connected remotely. Enabling UFW with a default-deny incoming policy
# and no SSH rule will immediately drop your own SSH session with no
# way to reconnect — you would need physical access to the machine
# to fix it.
