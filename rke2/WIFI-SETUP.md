# WiFi on Ubuntu Server 24.04 (netplan)

Ubuntu Server has no NetworkManager by default. WiFi is configured with a **netplan** YAML file
and run by systemd-networkd + wpa_supplicant. Do this on each node **at its own console**
(keyboard + screen), not over SSH, because you're changing that node's network.

Example values (replace them with yours):

| | node-01 | node-02 |
| --- | --- | --- |
| WiFi interface | `wlp2s0` | `wlp2s0` |
| IP | 192.168.1.21 | 192.168.1.22 |
| Router | 192.168.1.1 | 192.168.1.1 |

---

## 1. Find the WiFi interface and check it's usable

```bash
ip link                            # WiFi usually shows as wlp2s0 / wlo1 / wlan0
sudo rfkill list                   # if "Soft blocked: yes":
sudo rfkill unblock wifi
dpkg -l wpasupplicant | tail -1    # must start with "ii"; netplan needs it for WiFi
```

If `wpasupplicant` is missing, install it while the node has internet some other way: an
ethernet cable, or USB-tethering a phone (it shows up as an ethernet-like `usb0`/`enx...`
interface).
```bash
sudo apt update && sudo apt install -y wpasupplicant iw
```

If there's no `wl*` interface at all, the WiFi chip has no driver. Check
`lspci -k | grep -A3 -i network` (or `lsusb` for USB adapters); some chips need
`sudo apt install linux-firmware` or a vendor driver.

## 2. The netplan file

```bash
sudo nano /etc/netplan/60-wifi.yaml
```

**Static IP** (use this for cluster nodes, which need fixed addresses):
```yaml
network:
  version: 2
  renderer: networkd
  wifis:
    wlp2s0:                       # your interface from step 1
      dhcp4: false
      addresses:
        - 192.168.1.21/24         # node-01; use .22 on node-02
      routes:
        - to: default
          via: 192.168.1.1        # your router
      nameservers:
        addresses: [192.168.1.1, 1.1.1.1]
      access-points:
        "YourWifiName":
          password: "YourWifiPassword"
```

**DHCP** (quick test). Replace `addresses` / `routes` / `nameservers` with:
```yaml
      dhcp4: true
```
If you stay on DHCP, add a DHCP reservation on the router so the IP never changes.

Options under the SSID:
```yaml
        "YourWifiName":
          password: "YourWifiPassword"
          hidden: true            # hidden network
          band: 5GHz              # force 5 GHz (faster, if the router has it)
```

If `/etc/netplan/50-cloud-init.yaml` still has an unused ethernet entry, add
`optional: true` under that interface so boot doesn't wait ~2 minutes for a cable:
```yaml
  ethernets:
    enp1s0:
      dhcp4: true
      optional: true
```

## 3. Apply it

```bash
sudo chmod 600 /etc/netplan/*.yaml   # netplan warns if others can read the WiFi password
sudo netplan generate                # syntax check: silence means OK
sudo netplan try                     # applies; press Enter within 120 s to keep, else it reverts
sudo netplan apply
```

Stop cloud-init from overwriting the network config on the next reboot:
```bash
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

## 4. Check it's connected

```bash
ip -4 addr show wlp2s0     # shows your IP
iw dev wlp2s0 link         # SSID, signal (dBm), bitrate
ping -c3 192.168.1.1       # router
ping -c3 1.1.1.1           # internet
ping -c3 ubuntu.com        # DNS
resolvectl status wlp2s0   # DNS servers in use
```

Signal: -30 to -60 dBm is good, -70 is weak, below -80 drops.

If it doesn't connect:
```bash
systemctl status netplan-wpa-wlp2s0          # the wpa_supplicant unit netplan creates
journalctl -u netplan-wpa-wlp2s0 -n 50       # wrong password shows as "4-Way Handshake failed"
journalctl -u systemd-networkd -n 50
```

## 5. Test node-to-node (matters for the cluster)

From node-01:
```bash
ping -c5 192.168.1.22             # latency; a few ms is fine on WiFi
nc -vz 192.168.1.22 22            # TCP reaches the other node
```

If the internet works but the two nodes **can't reach each other**, the router has **AP / client
isolation** turned on (often part of "guest network" mode). Turn it off for this network, or put
the nodes on the main (non-guest) network.

Throughput:
```bash
sudo apt install -y iperf3
iperf3 -s                          # on node-02
iperf3 -c 192.168.1.22 -t 10       # on node-01
```

## 6. Turn off WiFi power saving

Power saving causes random latency spikes and dropped connections, which etcd, kubelet and
SSH all notice.

```bash
sudo tee /etc/systemd/system/wifi-powersave-off.service >/dev/null <<'EOF'
[Unit]
Description=Disable WiFi power saving
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/iw dev wlp2s0 set power_save off

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-powersave-off
iw dev wlp2s0 get power_save       # "Power save: off"
```

## 7. Reboot test

```bash
sudo reboot
# after boot, on the console or over SSH from the laptop:
ip -4 addr show wlp2s0 && iw dev wlp2s0 get power_save && ping -c3 192.168.1.1
```

---

## Using WiFi nodes for the RKE2 cluster

- In `rke2/cluster-2node.env`, use the WiFi IPs:
  ```bash
  SERVER_NODES="node-01:192.168.1.21"
  AGENT_NODES="node-02:192.168.1.22"
  INGRESS_IP="192.168.1.21"
  ```
- If a node has **both** ethernet and WiFi, set `CANAL_IFACE="wlp2s0"` so pod-to-pod traffic uses
  WiFi (otherwise Canal picks the interface holding the default route).
- Do the WiFi setup **before** `rke2/install-cluster.sh`. Changing a node's IP after RKE2 is
  installed means reinstalling RKE2 on it (`rke2/uninstall.sh cluster`, then install again).
- Fine for the 2-node test cluster. Expect slower image pulls and more latency than a cable.
  For the 4-node cluster, prefer wired: Kafka replication, SeaweedFS replication and Spark
  shuffles are all node-to-node traffic.

## Quick reference

| Task | Command |
| --- | --- |
| Show interfaces | `ip link` / `ip -4 addr` |
| Unblock radio | `sudo rfkill unblock wifi` |
| Scan networks | `sudo iw dev wlp2s0 scan \| grep -E 'SSID\|signal'` |
| Validate / apply | `sudo netplan generate` / `sudo netplan try` / `sudo netplan apply` |
| Link status | `iw dev wlp2s0 link` |
| Logs | `journalctl -u netplan-wpa-wlp2s0 -n 50` |
| Power save | `iw dev wlp2s0 get power_save` |
