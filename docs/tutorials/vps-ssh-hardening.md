# VPS Baseline Hardening (SSH key-only + default-deny firewall)

A reusable checklist for the first 15 minutes on **any** fresh Linux VPS
(Ubuntu/Debian), before installing anything else on it. Provider-agnostic —
same steps whether it's a $5/mo VPS, an EC2 instance, or an Azure VM.

## What you end up with
- A non-root sudo user (root itself can no longer log in over SSH)
- Key-only SSH auth (no password guessing possible)
- Firewall default-deny, only explicitly-allowed ports open
- fail2ban banning IPs that hammer SSH
- A swapfile (reliability, not security — prevents OOM kills under memory
  pressure)

## The one rule that matters more than any command

**Never cut off your current access before you've verified the replacement
works, from a *separate* session.** Every lockout happens by breaking this
rule — restarting sshd or closing a terminal before confirming the new user
can actually log in. Keep the original session open until step 5 is
confirmed in a brand new window.

---

## Steps

### 1. Create a non-root sudo user
```bash
adduser cloud                 # prompts for a password, doesn't matter, password auth gets disabled later
usermod -aG sudo cloud        # root-equivalent access, but only via `sudo`, one command at a time, logged
```
Why not just use root day to day: root actions aren't attributed to
anyone and have no blast-radius limit. `sudo` logs every escalated command
with the real username in `/var/log/auth.log` — this is the same "no
standing superuser access" principle behind least-privilege IAM roles in
any cloud.

### 2. Copy your public key over — BEFORE touching sshd config
```bash
# on your local machine
ssh-copy-id cloud@<vps-ip>
```
This appends your key to `~/.ssh/authorized_keys` on the VPS for that user,
using your still-working password auth to get in the one time it's needed.
**Do this before disabling password auth** — obvious in hindsight, but it's
the single most common way people lock themselves out.

If you forget this step and only realize after disabling password auth,
see [Recovery](#recovery-if-you-skipped-step-2) below.

### 3. Verify key login works, in a new terminal, without closing anything
```bash
ssh cloud@<vps-ip>
```
Only proceed once this succeeds cleanly.

### 4. Harden sshd
```bash
sudo sed -i \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  /etc/ssh/sshd_config
sudo systemctl restart ssh
```
- `PasswordAuthentication no` — removes password guessing as an attack
  vector entirely, key possession is now required.
- `PermitRootLogin no` — root can't SSH in at all anymore, by password or
  key. Compromising any single key only gets an attacker an unprivileged
  shell, which still needs a logged `sudo` escalation to do anything
  dangerous.

### 5. Re-verify in a brand new session before closing the old one
```bash
ssh cloud@<vps-ip>     # must work
ssh root@<vps-ip>      # must now fail
```
Only close your original session once both of these behave as expected.

### 6. Default-deny firewall, explicit allow list only
```bash
sudo apt update && sudo apt install -y ufw fail2ban
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable
sudo systemctl enable --now fail2ban
```
The provider's own firewall/security-group panel may say "all ports open"
— that's a different layer. `ufw` is the OS-level firewall and should
*always* be default-deny regardless of what the provider allows through.
As you add services later (a VPN port, a web server, etc.), add one
explicit `ufw allow` rule per service — never flip the default to allow.

`fail2ban` adds a second layer on top: even key-only auth gets hammered by
scanning bots constantly; it auto-bans IPs after repeated failed attempts.

### 7. Swapfile (reliability, do this on any RAM-constrained box)
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```
Without this, anything that spikes memory (a container build, a k8s
control plane, a JVM app) gets silently OOM-killed instead of just slowing
down. Size it to roughly your RAM, more if disk space allows.

---

## Verification checklist
```bash
ssh cloud@<vps-ip>            # works
ssh root@<vps-ip>             # fails ("Permission denied")
sudo ufw status verbose       # default deny (incoming), only SSH allowed
free -h                       # swap column shows your swapfile size, active
sudo systemctl status fail2ban  # active (running)
```

---

## Recovery if you skipped step 2

If you disabled password auth / restarted sshd before ever copying a key
over, but you still have **one working session** open (even just password
auth that hasn't been logged out of yet):

```bash
# in the still-open session, as the target user (no sudo needed — you own your own home dir)
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA...your-public-key..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
Then test from a **new** terminal tab before closing the original. If
`~/.ssh/authorized_keys` ends up owned by `root` (e.g. because you used
`sudo` by habit), sshd will silently reject the key with no useful client
error — check with `namei -l ~/.ssh/authorized_keys` and confirm every
level of the path is owned by the target user, not root.

If you have **no working session left at all**, you need out-of-band
access — most VPS/cloud providers offer a web console/serial console in
their dashboard that bypasses SSH entirely for exactly this scenario.

---

## Generalizing this beyond one project

- Distro-portable: swap `apt`/`ufw` for `dnf`/`firewalld` on RHEL-family,
  or the cloud provider's native equivalent (Security Groups on AWS, NSGs
  on Azure) — the *pattern* (non-root identity, key-only auth, default
  deny + explicit allow, verify-before-you-cut-off) is identical everywhere.
- Same discipline applies one layer up too: Azure custom RBAC roles
  instead of `Owner`, Kubernetes RBAC instead of cluster-admin, NSGs
  instead of "allow all" — this VPS setup is the smallest possible version
  of a pattern you'll rebuild at every layer of a real cloud stack.
