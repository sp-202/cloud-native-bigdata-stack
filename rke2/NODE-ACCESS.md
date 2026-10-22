# Node access: SSH keys + passwordless sudo (Ubuntu)

A general reference for preparing any Ubuntu node so the `rke2/*.sh` scripts can drive it from
your laptop (WSL is fine). The scripts need two things on every node:

1. **SSH login with a key**, no password prompt;
2. **`sudo` without a password** for that user (they run `sudo -n ...`, which fails instead of
   prompting).

Below, the laptop is where the repo is and where you run the scripts. `ubuntu` is the login
user on the nodes (replace it with yours). The IPs are examples:

| Node | IP |
| --- | --- |
| node-01 | 192.168.1.21 |
| node-02 | 192.168.1.22 |

---

## 1. On the laptop: create an SSH key (once)

```bash
ls ~/.ssh/id_ed25519.pub 2>/dev/null || ssh-keygen -t ed25519 -C "rke2-admin" -f ~/.ssh/id_ed25519 -N ""
```

`-N ""` means no passphrase, so the scripts never stop to ask. If you prefer a passphrase, load
it into an agent before running the scripts: `eval "$(ssh-agent)"; ssh-add ~/.ssh/id_ed25519`.

## 2. From the laptop: copy the key to each node

You type the node's password **once per node** here, never again after that.

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@192.168.1.21
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@192.168.1.22
```

If `ssh-copy-id` isn't available:
```bash
cat ~/.ssh/id_ed25519.pub | ssh ubuntu@192.168.1.21 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Check that each node logs in with no password prompt:
```bash
ssh ubuntu@192.168.1.21 hostname
ssh ubuntu@192.168.1.22 hostname
```

## 3. On each node: passwordless sudo

Log in to the node (`ssh ubuntu@192.168.1.21`) and run the block below. It asks for your sudo
password **one last time**:

```bash
U=$(whoami)
echo "$U ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-$U-nopasswd >/dev/null
sudo chmod 0440 /etc/sudoers.d/90-$U-nopasswd
sudo visudo -cf /etc/sudoers.d/90-$U-nopasswd      # must print "parsed OK"
```

Then `exit` and repeat on the next node.

Why a file in `/etc/sudoers.d/` and not editing `/etc/sudoers`? It's a separate file just for
this user, so it's easy to remove later, and `visudo -c` validates it. A typo in the main
sudoers file can lock you out of sudo entirely.

To do both nodes **from the laptop in one go** instead (`-t` gives sudo a terminal for that last
password prompt):
```bash
for ip in 192.168.1.21 192.168.1.22; do
  ssh -t ubuntu@$ip 'U=$(whoami); echo "$U ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-$U-nopasswd >/dev/null && sudo chmod 0440 /etc/sudoers.d/90-$U-nopasswd && sudo visudo -cf /etc/sudoers.d/90-$U-nopasswd'
done
```

## 4. From the laptop: verify (what the scripts check first)

Both lines must print `ok` **without any password prompt**:
```bash
for ip in 192.168.1.21 192.168.1.22; do
  ssh -o BatchMode=yes ubuntu@$ip 'sudo -n true && echo "$(hostname) ok"'
done
```

`BatchMode=yes` makes ssh fail instead of asking for a password, which is exactly how the scripts
connect. If this passes, `rke2/install-cluster.sh` can reach the nodes.

## 5. Optional: short names in `~/.ssh/config`

So you can type `ssh node-01`:
```bash
cat >> ~/.ssh/config <<'EOF'
Host node-01
  HostName 192.168.1.21
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519
Host node-02
  HostName 192.168.1.22
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519
EOF
chmod 600 ~/.ssh/config
```

The scripts still use the IPs, `SSH_USER` and `SSH_KEY` from `rke2/cluster-2node.env`, so set
those to match:
```bash
SERVER_NODES="node-01:192.168.1.21"
AGENT_NODES="node-02:192.168.1.22"
SSH_USER="ubuntu"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="22"
```

---

## Running from the laptop (WSL) vs. from node-01

- **Laptop:** steps 1–4 as written. The laptop needs network access to both node IPs (SSH :22,
  the Kubernetes API :6443 for `kubectl`, and :80 for the UIs).
- **node-01 itself:** same steps, run on node-01. Also copy the key to node-01's **own IP**
  (`ssh-copy-id ubuntu@192.168.1.21` from node-01), because the scripts SSH to every node,
  including the one they run on.

WSL notes:
- Use the WSL home (`~/.ssh`), not the Windows `C:\Users\...\.ssh`.
- If `ssh` complains about key permissions: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519`.
- WSL reaches LAN IPs through Windows. If `ssh 192.168.1.21` times out from WSL but works from
  Windows, check the Windows firewall/VPN.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Permission denied (publickey)` | key not on the node: redo step 2; on the node check `~/.ssh` is 700 and `~/.ssh/authorized_keys` is 600, owned by the user |
| `sudo: a password is required` | step 3 not applied for **this** user, or the file name has a `.` or `~` in it (sudo ignores those files in sudoers.d): `ls -l /etc/sudoers.d/` |
| `sudo: unable to resolve host ...` | harmless warning; fix by adding the hostname to `/etc/hosts` (`127.0.1.1 <hostname>`) |
| `Host key verification failed` | a node was reinstalled and has a new host key: `ssh-keygen -R 192.168.1.21` and connect again |
| ssh hangs / times out | wrong IP, node down, or a firewall on the path: `ping 192.168.1.21`, `nc -vz 192.168.1.21 22` |

## Undo later (tighten the nodes again)

**(each node)**
```bash
sudo rm /etc/sudoers.d/90-$(whoami)-nopasswd
```
To revoke the laptop's key, delete its line (it ends in `rke2-admin`) from `~/.ssh/authorized_keys`.

Security note: passwordless sudo means anyone with this SSH key is root on the nodes. Keep
`~/.ssh/id_ed25519` private, and remove the sudoers file once the cluster no longer needs
script-driven changes.
