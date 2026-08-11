# SOC / SIEM Home Lab

**Status:** 🟡 In progress — building a home Security Operations Center to practice the full **attack → detect → verify** pipeline that SOC analysts work daily.

A self-built lab where I monitor endpoints with a SIEM, launch real attacks from an attacker VM, and confirm detections across three layers (endpoint source log → SIEM engine output → dashboard). Built and documented from scratch as hands-on reinforcement of my CompTIA Security+ knowledge.

## Architecture

Four virtual machines on an isolated VirtualBox **host-only** network (`192.168.56.0/24`):

| VM | Role | IP |
|----|------|----|
| Wazuh Server (Ubuntu 24.04) | SIEM — manager, indexer, dashboard | 192.168.56.10 |
| Ubuntu Endpoint | Monitored host (Wazuh agent) | 192.168.56.20 |
| Windows Endpoint | Monitored host (Wazuh agent + Sysmon) | 192.168.56.30 |
| Kali Linux | Attacker | 192.168.56.40 |

## What this lab demonstrates

- **SIEM operations:** deploying Wazuh, enrolling agents, reading and triaging alerts
- **Host-based detection:** Windows Event Logs, Sysmon, Linux auth logs, file integrity
- **Attack simulation:** reconnaissance (Nmap) and exploitation (brute force, Metasploit) from Kali
- **Detection engineering:** writing and tuning custom Wazuh rules
- **Verification discipline:** cross-checking every detection from raw source log → `alerts.json` → dashboard, so alerts are understood, not just trusted

## Tools

`Wazuh` · `Sysmon` · `Kali Linux` · `Nmap` · `Hydra` · `Metasploit` · `Windows Active Directory` (stretch) · `Suricata` (stretch) · `VirtualBox`

## Roadmap

- [x] **M0** — Prep: hypervisor, ISOs, host-only network
- [x] **M1** — Wazuh server up, dashboard reachable
- [x] **M2** — Ubuntu endpoint reporting as a Wazuh agent with live events _(Windows endpoint deferred)_
- [x] **M3** — Attack from Kali (recon + brute force) detected in Wazuh with MITRE ATT&CK correlation
- [ ] **M4** — Detection + three-layer verification + one custom rule
- [ ] Stretch — Suricata forwarded into Wazuh (network + host visibility)
- [ ] Stretch — Active Directory domain + domain-attack detection

Full step-by-step build guide: [`SOC Lab - Build Plan.md`](SOC%20Lab%20-%20Build%20Plan.md)

## Progress

### Milestone 1 — Wazuh SIEM deployed
Single-node Wazuh (manager, indexer, dashboard) installed on Ubuntu Server 24.04, reachable over the isolated host-only network at `192.168.56.10`. Dashboard up and ready to receive agents.

![Wazuh dashboard after initial deployment](screenshots/m1-wazuh-dashboard.png)

### Milestone 2 — First endpoint enrolled and reporting
Enrolled an Ubuntu Server endpoint (`192.168.56.20`) as a Wazuh agent over the host-only network. Verified the full data pipeline end to end — the agent connects to the manager over TCP/1514 (AES-encrypted), and generated activity (successful `sudo`, authentication events) is decoded, rule-matched, and surfaced in the Threat Hunting dashboard, correlated to PCI DSS requirements. Troubleshot an initial "never connected" state by pinning the manager address in the agent config and restarting the service.

*Windows endpoint deferred — Windows 11 hit VirtualBox EFI/boot issues; will revisit with a Windows 10 VM.*

![Ubuntu agent events in the Wazuh Threat Hunting dashboard](screenshots/m2-ubuntu-agent-events.png)

### Milestone 3 — Attack simulation & detection
Generated a live attack from a Kali Linux VM (`192.168.56.103`) against the monitored Ubuntu endpoint (`192.168.56.20`) and confirmed end-to-end detection in the SIEM. Recon with `nmap -sV` fingerprinted the exposed SSH service, then an SSH brute force with Hydra (`hydra -l sam -P /tmp/pw.txt ssh://192.168.56.20`) hammered the endpoint. The login did not succeed — as intended, the flood of failed authentications is the detection trigger. Wazuh decoded the sshd authentication failures and surfaced them on the endpoint's MITRE ATT&CK dashboard, correlating the activity to ATT&CK tactics (Initial Access, Persistence, Privilege Escalation, and Defense Evasion under the Valid Accounts technique). This closes the loop from the M2 pipeline: telemetry now feeds not just raw events but rule-matched, ATT&CK-mapped detections — the core function of a SOC.

*Lab note: this session opened with a SIEM outage — the Wazuh server's 24 GB disk hit the OpenSearch flood-stage watermark (95%) from unbounded event archiving in `/var/ossec`. Diagnosed the disk exhaustion, cleared the archive logs, disabled `logall`/`logall_json`, and restored the indexer → manager → dashboard stack. Real operations experience recovering a SIEM knocked offline.*

![Kali SSH brute force detected and correlated to MITRE ATT&CK tactics on ubuntu-endpoint](screenshots/m3-kali-attack-mitre.png)

## Detections documented

*(Add each as you complete it — attack, rule that caught it, and the three-layer screenshots.)*

## Author

**Samuel Kaiser** — Cybersecurity Analyst · CompTIA Security+
GitHub: [brimblenot](https://github.com/brimblenot) · LinkedIn: [samuel-thomas-kaiser](https://www.linkedin.com/in/samuel-thomas-kaiser/)
