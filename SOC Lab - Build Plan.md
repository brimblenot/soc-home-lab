---
title: SOC Lab - Build Plan (Wazuh + Suricata + AD)
date: 2026-08-06
tags: [lab, soc, wazuh, suricata, active-directory, in-progress]
target: Basics running by Aug 15, 2026
host: Laptop, 32 GB RAM, SSD (need ~200 GB free)
---

# SOC Lab — Build Plan

**Goal:** A working home Security Operations Center: monitored endpoints, a Kali attacker, and a full **attack → alert → verify** pipeline in Wazuh. "Basics" = Milestones 0–4 done by **Aug 15**. Suricata + Active Directory are stretch goals after.

**How to use this:** work top to bottom, check each box, and don't move on until the "✅ Done when" line is true. Commands are copy-paste ready. Only bring a problem back to chat if a step fails after you've tried its troubleshooting note.

---

## Ground rules (read once)

- **Isolation:** every VM sits on a VirtualBox **Host-Only network** — never Bridged. Nothing in this lab should touch your real home network or the internet during attacks.
- **RAM discipline:** you do NOT run every VM at once. Keep Wazuh + endpoints on; power Kali on only while attacking, then shut it down.
- **Snapshot before big changes:** in VirtualBox, right-click a VM → Snapshot → Take, before installs that could break. Easy rollback.
- **Naming/IPs used in this guide (host-only subnet `192.168.56.0/24`):**
  - Wazuh server → `192.168.56.10`
  - Ubuntu endpoint → `192.168.56.20`
  - Windows endpoint → `192.168.56.30`
  - Kali attacker → `192.168.56.40`

---

## Milestone 0 — Prep (Aug 6–7)

- [x] **Confirm free disk:** need ~200 GB free on an SSD. (Windows: This PC → C: drive.)
- [x] **Install VirtualBox** (+ the matching Extension Pack) from virtualbox.org.
- [x] **Download ISOs** (put them all in one folder):
  - Ubuntu Server 24.04.4 LTS — ubuntu.com/download/server
  - Windows 10 (or 11) Evaluation — microsoft.com/evalcenter (90-day, free)
  - Kali Linux (VirtualBox image or ISO) — kali.org/get-kali
  - *(optional, easy target)* Metasploitable2 — sourceforge.net/projects/metasploitable
- [x] **Create the Host-Only network:** VirtualBox → Tools (menu) → Network → Host-only Networks → **Create**. Note its name (usually `vboxnet0`). Set/confirm its subnet as `192.168.56.1/24` and **disable its DHCP server** (you'll use static IPs).

**✅ Done when:** VirtualBox installed, four ISOs downloaded, host-only network `vboxnet0` exists on `192.168.56.0/24`.

---

## Milestone 1 — Wazuh server (Aug 8–9)

**1. Create the VM:** New → Name `wazuh-server`, Type Linux / Ubuntu 64-bit. **6 GB RAM**, **2 CPU**, **50 GB disk**. Attach the Ubuntu Server ISO.

**2. Networking:** VM Settings → Network → Adapter 1 = **Host-only Adapter** → `vboxnet0`.

**3. Install Ubuntu Server:** boot the VM, run the installer (defaults are fine), create your user, and **install OpenSSH server** when offered. During network setup, set a **static IP** for the interface: address `192.168.56.10/24`, gateway blank, nameserver `8.8.8.8` (Wazuh install needs temporary internet — see note).

> Internet note: the Wazuh installer downloads packages, so for Milestone 1 **only**, temporarily add a second adapter (Settings → Adapter 2 = NAT) so the VM can reach the internet to install. After install succeeds, you can remove/disable Adapter 2 to keep the lab isolated.

**4. Update, then install Wazuh (single-node, all-in-one):**
```bash
sudo apt update && sudo apt -y upgrade
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```
The script prints the **admin password** at the end — copy it somewhere safe. (Re-show later with `sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt`.)

**5. Log in:** from your host browser go to `https://192.168.56.10` → accept the self-signed cert → user `admin`, password from step 4.

- **Troubleshooting:** if the page won't load, on the server run `sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard` — all three should be `active (running)`. If the indexer is dead, it's almost always low RAM; give the VM 6 GB and reboot.

**✅ Done when:** the Wazuh dashboard loads at `https://192.168.56.10` and you can log in.

---

## Milestone 2 — Endpoints reporting (Aug 10–11)

### Ubuntu endpoint
**1. VM:** New → `ubuntu-endpoint`, 2 GB RAM, 1–2 CPU, 25 GB disk, Network = Host-only `vboxnet0`, static IP `192.168.56.20/24`. Install OpenSSH server.

**2. Enroll the Wazuh agent** — in the dashboard: **Agents → Deploy new agent** → pick Linux/DEB amd64 → set the **manager IP `192.168.56.10`** → copy the generated command and run it on the Ubuntu endpoint, then:
```bash
sudo systemctl enable wazuh-agent && sudo systemctl start wazuh-agent
```

### Windows endpoint
**1. VM:** New → `win-endpoint`, 4 GB RAM, 2 CPU, 50 GB disk, Network = Host-only `vboxnet0`. Install Windows, then set the adapter's IPv4 to static `192.168.56.30`, mask `255.255.255.0`.

**2. Enroll the Wazuh agent:** dashboard → Deploy new agent → Windows → manager IP `192.168.56.10` → run the given PowerShell command **as Administrator**, then `net start wazuh` (or `Start-Service WazuhSvc`).

**3. Install Sysmon (richer Windows telemetry):** download Sysmon (Sysinternals) + SwiftOnSecurity's `sysmonconfig-export.xml`, then in an admin prompt:
```powershell
.\Sysmon64.exe -accepteula -i sysmonconfig-export.xml
```
Then tell Wazuh to read the Sysmon channel: on the **Windows agent**, edit `C:\Program Files (x86)\ossec-agent\ossec.conf` and add inside `<ossec_config>`:
```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```
Restart the agent: `Restart-Service WazuhSvc`.

- **Troubleshooting:** if an agent shows "Never connected," it's almost always (a) wrong manager IP, or (b) the host-only firewall — confirm you can `ping 192.168.56.10` from the endpoint. On Windows, allow the agent through Windows Defender Firewall.

**✅ Done when:** dashboard → Agents shows **both** endpoints as **Active**.

---

## Milestone 3 — Attack (Aug 12–13) — ✅ COMPLETE (Aug 11)

**Result:** ran nmap + Hydra SSH brute force from Kali against the Ubuntu endpoint; Wazuh detected the failed-auth flood and correlated it to MITRE ATT&CK tactics on the endpoint's ATT&CK dashboard. Note: Kali came up on DHCP as `192.168.56.103` (not the planned static `.40`) — same host-only subnet, works fine. Also skipped rockyou in favor of a small inline `/tmp/pw.txt` list to avoid path/paste issues.

**1. Kali VM:** import/create `kali-attacker`, 4 GB RAM, 2 CPU, Network = Host-only `vboxnet0`, static IP `192.168.56.40/24`. (Power this on ONLY during attacks.)

**2. Recon:**
```bash
nmap -sV 192.168.56.20   # scan the Ubuntu endpoint
```

**3. SSH brute force (the clean, reliable demo):** on Kali:
```bash
# small wordlist for the demo
hydra -l root -P /usr/share/wordlists/rockyou.txt.gz ssh://192.168.56.20 -t 4 -f
```
(Unzip rockyou first if needed: `sudo gunzip /usr/share/wordlists/rockyou.txt.gz`. You don't need it to *succeed* — the failed-login storm is what generates the detection.)

**4. Watch it land:** in the Wazuh dashboard → **Security events**, filter to the Ubuntu agent. You should see a burst of authentication-failure events during the attack.

**✅ Done when:** you ran nmap + hydra from Kali and can see the resulting events for `192.168.56.20` in the dashboard.

---

## Milestone 4 — Detection + three-layer verification (Aug 14–15) ← FINISH LINE — ✅ COMPLETE (Aug 11)

**Result:** verified the SSH brute force across all three layers (auth.log → alerts.json → dashboard). Built-in rules fired as `5760` → `2502` (level 10, T1110) — note the actual rule IDs were 5760/2502, not the 5710/5712/5763 the plan guessed. Found and fixed a real detection gap: the endpoint was collecting journald but not `/var/log/auth.log`, so sshd failures never alerted until that source was added. Wrote custom rule **100002** (level 12, 8 failures/60s, same source IP) — debugged a duplicate-ID collision with the shipped example rule 100001 — and confirmed it firing on a live attack.



Wazuh ships with SSH brute-force rules out of the box (rule IDs ~5710/5712/5763). Confirm they fired, then **verify across all three layers** — this is the step that separates real understanding from tutorial-following.

**Layer 1 — Source log (ground truth on the endpoint).** On the Ubuntu endpoint:
```bash
sudo grep "Failed password" /var/log/auth.log | tail -20
```
Screenshot this.

**Layer 2 — Engine output (raw Wazuh alert on the manager).** On the Wazuh server:
```bash
sudo grep -i "sshd" /var/ossec/logs/alerts/alerts.json | tail -5
# or the human-readable log:
sudo grep -i "authentication" /var/ossec/logs/alerts/alerts.log | tail -20
```
Confirm the same event appears as a decoded alert (you'll see `rule.id`, `rule.description`, `srcip`). Screenshot this.

**Layer 3 — Dashboard.** In Security events, open the matching alert card (e.g., "sshd: Multiple authentication failures"). Screenshot this.

> The point: the *same* attack is traced from raw host log → Wazuh's rule-matched JSON → the GUI. Show all three side by side in your writeup.

**Write ONE custom rule (shows detection engineering).** On the Wazuh server, edit `/var/ossec/etc/rules/local_rules.xml` and add a rule that flags an nmap-style scan or tightens brute-force thresholds, e.g.:
```xml
<group name="local,recon,">
  <rule id="100100" level="10" frequency="8" timeframe="60">
    <if_matched_sid>5710</if_matched_sid>
    <description>Possible SSH brute force: 8+ auth failures in 60s from same source</description>
  </rule>
</group>
```
Restart: `sudo systemctl restart wazuh-manager`. Re-run the hydra attack and confirm rule **100100** fires. Screenshot it.

**✅ Done by Aug 15 when:** you have a documented attack → alert with **all three verification layers** captured, plus **one custom rule** you wrote firing on demand.

---

## Stretch goals (after Aug 15)

- [ ] **Add Suricata** on the Ubuntu endpoint (or a gateway VM), then forward its `eve.json` into Wazuh so **network** detections sit beside **host** detections in one dashboard. This gives you both visibility planes.
- [ ] **Build a Windows Active Directory domain** (add a Windows Server DC), join the Windows endpoint, and detect a domain attack (e.g., Kerberoasting) — enterprise realism.
- [ ] **Add Metasploitable2** as a soft target for quick, repeatable exploits.

---

## Writeup checklist (for the repo + portfolio)

- [ ] Architecture diagram (the 4 VMs + host-only subnet)
- [ ] Attack steps with commands
- [ ] The three-layer verification screenshots for at least one detection
- [ ] Your custom rule + explanation of what it catches and why
- [ ] Short "what I learned about the attack-to-detection pipeline" reflection

> When published, link it from the [portfolio home](../README.md) and flip the SOC lab line from "in progress" to done.
