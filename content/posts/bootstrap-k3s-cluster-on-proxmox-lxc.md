---
title: "Proxmox: k3s-kluster på 3× LXC (241–243) med ett skript"
date: 2026-02-22T02:10:00+01:00
tags: ["k3s", "kubernetes", "proxmox", "lxc"]
summary: "Anteckning: hur jag skapade 3 LXC-containrar på ah1-paulina och fick ett fungerande k3s-kluster + användning av kubeconfig (bonus: inventering av labbet)"
---

## Kort anteckning till mig själv i framtiden

Idag var en lång februarilördag framför datorn medan snön föll över Malmö utanför fönstret. Efter att ha flyttat min prod-server till Hetzner, återupplivat **den här** hemsidan, börjat migrera till forgejo från gitea (från gitlab) och hyrt en 10TB stor "Storage Box" att nattligen, med Rsync över SSH, backa upp ah1-superkojan och ah3-nadja till - så fastnade jag i Hetzners tabeller över **BILLIGA BILLIGA BILLIGA** maskiner med kryptiska namn och lika kryptiska regler. SJÄLVKLART skulle jag hyra _minst_ tre servrar till och driftsätta forgejo ([git.ahenriksson.com](https://git.ahenriksson.com)) med KUBERNETES. Gud vad anställningsbart, modernt och coolt tänkte jag och i ett rus klickade på knapp efter knapp tills jag hade spunnit igång ett helt datacenter där borta i Helsingfors.

Sedan såg jag hur många €/månad mitt vackra projekt skulle kosta och kom på bättre tankar - varför inte slippa labba med ångest och sätta upp kubernetes-klustret på min egen hårdvara? Min Proxmox-server **ah1-paulina** står ju en meter ifrån mig här i vardagsrummet, jag hade glömt det.

Så istället för att labba mer i “hyrd miljö” skrev jag ett skript som bara **skapar tre LXC-containers** och installerar **k3s** på dem. No hands.

Det viktiga: det här var inte “jag ska bygga något vackert”. Det var “jag vill kunna köra detta igen om 6 månader när jag glömt allt”.

### För kontext: Referens/inventering av hårdvara februari 2026

- **ah1-paulina**: en tystgående Proxmox-server med jättemånga kärnor, äkta ECC-RAM trots världsläget och 2×10G-uppkoppling (LACP) till lagring (vilket jag motiverade mig själv var fullständigt nödvändigt då iSCSI-hårddiskarna faktiskt ligger på NVMe och förtjänar att nå upp till sin ickeflaskhalsade potential).

- **ah1-superkojan**: en NAS/ful-"SAN", också med 2×10G (LACP), där hela mitt digitala liv ligger sparat på tre ZFS-pooler:
  1. 6×4TB SAS-HDD i raidz2 + 2× speglade NVMe-diskar för metadata och småfiler ("Special VDEV"), avsedd för backups av fysiska och virtuella maskiner.
  2. 6×1TB SATA-SSD i raidz2 för media- och fillagring.
  3. 4×1TB NVMe i RAID10-topologi, för lagring där prestanda behövs).

- **ah1-angelika:**: GPU-server med 11 Nvidia-kort för AI-grejer, mer om den i kommande anteckningar...

- **ah3-nadja**: en offsite TrueNAS-server på hemlig ort, där ah1-superkojan backas upp till.

![Homelab i vardagsrummet (feb 2026) — servrar 30 cm från soffan, som en normal människa.](/images/hemlabb_vardagsrum_februari_2026.jpeg)

### Miljö / antaganden

- Proxmox-host: `ah1-paulina`
- LXC-ID:n: `241` (control plane), `242` + `243` (workers)
- Nät: `192.168.200.0/24`
  - gateway: `192.168.200.1`
  - DNS: `192.168.200.211`
- Bridge: `vmbr0`
- Storage:
  - container rootfs: `local-zfs`
  - templates: `local` (måste ha `vztmpl` content)
- Körs som root på Proxmox-hosten.

### Vad skriptet gör (så jag slipper läsa hela koden)

1. Kollar att jag kör som root och att Proxmox-kommandon finns (`pct`, `pveam`, `pvesm`, osv).
2. Ser till att det finns en Debian-template (helst Debian 13, annars Debian 12, annars första Debian den hittar) och laddar ner om den saknas.
3. Fixar host-grejer som k3s brukar vilja ha (moduler + sysctl).
4. Skapar 3 st. LXC (privileged + nesting) med fasta IP:n och SSH-nyckel.
5. Patchar LXC-config så k3s inte gnäller ihjäl sig i container (apparmor/cgroup/dev/kmsg).
6. Provisionerar varje container (apt update med retries, install av baspaket, locale, timesync, bash completion, PS1).
7. Installerar k3s server på `241`.
8. Hämtar token från servern och joinar `242` + `243` som agents.
9. Dumpar `kubeconfig` på Proxmox-hosten och byter ut `127.0.0.1` till serverns riktiga IP.

Resultat: ett faktiskt fungerande kluster, och jag får en kubeconfig jag kan använda direkt.

---

## Så kör du (snabb referens)

1. Spara skriptet på Proxmox-hosten, t.ex. `/root/bootstrap-k3s-lxc-cluster.sh`

2. Kör:

```bash
chmod +x /root/bootstrap-k3s-lxc-cluster.sh
/root/bootstrap-k3s-lxc-cluster.sh
```

3. Testa klustret (skriptet skriver kubeconfig till /root/paulina-k3s.yaml):

```bash
export KUBECONFIG=/root/paulina-k3s.yaml
kubectl get nodes -o wide
kubectl get pods -A
```

4. Om jag vill ha kubeconfig “permanent” för min user:

```bash
mkdir -p ~/.kube
sudo cp /root/paulina-k3s.yaml ~/.kube/config
sudo chown -R "$USER:$USER" ~/.kube
chmod 600 ~/.kube/config
```

----

Skript: `bootstrap-k3s-lxc-cluster.sh`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "[ERROR] line $LINENO: $BASH_COMMAND" >&2' ERR

CONTAINER_STORAGE="local-zfs"
TEMPLATE_STORAGE="local"
BRIDGE="vmbr0"

DNS_SERVER="192.168.200.211"
GATEWAY="192.168.200.1"

CPU_CORES="4"
RAM_MIB="4096"
DISK_GB="20"

CONTROL_PLANE_ID="241"
WORKER_IDS=(242 243)

SSH_PUBLIC_KEY="$(
  cat <<'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM+kaytDi8B5Cw+GZ5l4wQck0r7ndFLLGtLWwYoXdOZ7 albin@goingeplan.se_2021-03-02
EOF
)"

declare -A HOSTNAMES=(
  [241]=ah1-k3s-241
  [242]=ah1-k3s-242
  [243]=ah1-k3s-243
)

REQUIRED_PACKAGES=(
  ca-certificates curl gnupg
  bash-completion
  git jq rsync unzip xz-utils lsb-release
  iproute2 iptables socat conntrack ipset
  nfs-common
)

OPTIONAL_PACKAGES=(
  htop tmux
  iperf iperf3
  micro emacs-nox
  bat eza
)

log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run this as root on the Proxmox host." >&2
    exit 1
  fi
}

require_commands() {
  local missing=0
  for c in pct pveam pvesm awk grep sed sysctl modprobe; do
    command -v "$c" >/dev/null 2>&1 || {
      echo "ERROR: missing command: $c" >&2
      missing=1
    }
  done
  ((missing == 0)) || exit 1
}

pick_template_storage() {
  if pvesm status -content vztmpl | awk 'NR>1 {print $1}' | grep -qx "${TEMPLATE_STORAGE}"; then
    echo "${TEMPLATE_STORAGE}"
    return
  fi

  local first
  first="$(pvesm status -content vztmpl | awk 'NR>1 {print $1; exit}')"
  if [[ -z "${first}" ]]; then
    echo "ERROR: no storage with 'vztmpl' content found." >&2
    exit 1
  fi

  log "TEMPLATE_STORAGE '${TEMPLATE_STORAGE}' has no vztmpl; using '${first}' instead."
  echo "${first}"
}

ensure_debian_template() {
  log "Updating template list..."
  pveam update >/dev/null

  local list
  list="$(pveam available -section system | awk '{print ($1=="system") ? $2 : $1}')"

  local tmpl=""
  tmpl="$(printf '%s\n' "$list" | grep -E '^debian-13-.*_amd64\.tar\.(zst|xz)$' | head -n1 || true)"
  if [[ -z "$tmpl" ]]; then
    log "Debian 13 template not found; falling back to Debian 12."
    tmpl="$(printf '%s\n' "$list" | grep -E '^debian-12-.*_amd64\.tar\.(zst|xz)$' | head -n1 || true)"
  fi
  if [[ -z "$tmpl" ]]; then
    log "No Debian 12/13 template found; picking the first Debian template available."
    tmpl="$(printf '%s\n' "$list" | grep -E '^debian-.*_amd64\.tar\.(zst|xz)$' | head -n1 || true)"
  fi

  if [[ -z "$tmpl" ]]; then
    echo "ERROR: no Debian template found in pveam." >&2
    echo "Check: pveam available -section system | head -n 50" >&2
    exit 1
  fi

  if ! pveam list "${TEMPLATE_STORAGE}" | grep -qF "${tmpl}"; then
    log "Downloading template ${tmpl} to ${TEMPLATE_STORAGE}..."
    pveam download "${TEMPLATE_STORAGE}" "${tmpl}"
  else
    log "Template ${tmpl} already present."
  fi

  echo "${tmpl}"
}

prepare_host_kernel() {
  log "Preparing host kernel bits for k3s (modules + sysctl)..."
  modprobe overlay || true
  modprobe br_netfilter || true

  cat >/etc/sysctl.d/99-k3s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
EOF

  sysctl --system >/dev/null || true
}

append_line_if_missing() {
  local file="$1"
  local line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >>"$file"
}

patch_container_config_for_k3s() {
  local id="$1"
  local conf="/etc/pve/lxc/${id}.conf"

  if [[ ! -f "$conf" ]]; then
    echo "ERROR: missing $conf" >&2
    exit 1
  fi

  log "Patching ${conf} for k3s in LXC..."
  append_line_if_missing "$conf" "lxc.apparmor.profile: unconfined"
  append_line_if_missing "$conf" "lxc.cgroup2.devices.allow: a"
  append_line_if_missing "$conf" "lxc.mount.auto: proc:rw sys:rw"
  append_line_if_missing "$conf" "lxc.mount.entry: /dev/kmsg dev/kmsg none bind,create=file,optional 0 0"
}

create_container() {
  local id="$1"
  local hostname="${HOSTNAMES[$id]}"
  local ip="192.168.200.${id}/24"

  log "Creating CT ${id} (${hostname})..."

  local tmpkey
  tmpkey="$(mktemp)"
  printf '%s\n' "${SSH_PUBLIC_KEY}" >"${tmpkey}"

  pct create "${id}" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
    --arch amd64 \
    --hostname "${hostname}" \
    --cores "${CPU_CORES}" \
    --memory "${RAM_MIB}" \
    --swap 0 \
    --rootfs "${CONTAINER_STORAGE}:${DISK_GB}" \
    --net0 "name=eth0,bridge=${BRIDGE},ip=${ip},gw=${GATEWAY}" \
    --nameserver "${DNS_SERVER}" \
    --onboot 1 \
    --ostype debian \
    --unprivileged 0 \
    --features keyctl=1,nesting=1 \
    --ssh-public-keys "${tmpkey}"

  rm -f "${tmpkey}"

  patch_container_config_for_k3s "${id}"
}

start_container() {
  local id="$1"
  log "Starting CT ${id}..."
  pct start "${id}"
}

wait_for_container() {
  local id="$1"
  log "Waiting for CT ${id} to become ready..."
  for _ in {1..30}; do
    if pct exec "${id}" -- bash -lc 'systemctl is-system-running --wait >/dev/null 2>&1 || true; true' >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
}

provision_container() {
  local id="$1"
  local req_pkgs="${REQUIRED_PACKAGES[*]}"
  local opt_pkgs="${OPTIONAL_PACKAGES[*]}"

  log "Provisioning CT ${id} (${HOSTNAMES[$id]})..."

  pct exec "${id}" -- bash -s -- "${req_pkgs}" "${opt_pkgs}" <<'EOS'
set -Eeuo pipefail
REQ_PKGS="$1"
OPT_PKGS="$2"

export DEBIAN_FRONTEND=noninteractive

for i in 1 2 3 4 5; do
  apt-get update && break || sleep 2
done

apt-get install -y $REQ_PKGS

for p in $OPT_PKGS; do
  apt-get install -y "$p" || true
done

if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  ln -sf /usr/bin/batcat /usr/local/bin/bat
fi

sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
locale-gen en_US.UTF-8 || true
update-locale LANG=en_US.UTF-8 || true

cat >/etc/systemd/timesyncd.conf <<'EOF'
[Time]
NTP=mmo1.ntp.se mmo2.ntp.se
FallbackNTP=pool.ntp.org
EOF
systemctl restart systemd-timesyncd || true
timedatectl set-ntp true || true

grep -q 'bash_completion' /etc/bash.bashrc || echo '[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion' >> /etc/bash.bashrc

cat >/etc/profile.d/zz-ps1.sh <<'EOF'
HOST_COLOR='\[\e[38;5;39m\]'
RESET='\[\e[0m\]'
export PS1="${HOST_COLOR}\u@\h ($(hostname -I | awk '{print $1}'))${RESET} \w\\$ "
EOF
EOS
}

install_k3s_control_plane() {
  local id="${CONTROL_PLANE_ID}"
  local server_ip="192.168.200.${CONTROL_PLANE_ID}"

  log "Installing k3s CONTROL PLANE on CT ${id} (${server_ip})..."

  pct exec "${id}" -- bash -s -- "${server_ip}" <<'EOS'
set -Eeuo pipefail
SERVER_IP="$1"

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server --node-ip ${SERVER_IP} --advertise-address ${SERVER_IP} --tls-san ${SERVER_IP}" \
  sh -s -

systemctl enable --now k3s
EOS
}

install_k3s_workers() {
  local server_ip="192.168.200.${CONTROL_PLANE_ID}"

  log "Fetching k3s token from control plane..."
  local token=""
  for _ in {1..30}; do
    token="$(pct exec "${CONTROL_PLANE_ID}" -- bash -lc 'cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || true' || true)"
    [[ -n "${token}" ]] && break
    sleep 2
  done

  if [[ -z "${token}" ]]; then
    echo "ERROR: failed to read node-token from ${CONTROL_PLANE_ID}." >&2
    exit 1
  fi

  log "Installing k3s WORKERS on ${WORKER_IDS[*]}..."
  for id in "${WORKER_IDS[@]}"; do
    local ip="192.168.200.${id}"
    pct exec "${id}" -- bash -s -- "${server_ip}" "${token}" "${ip}" <<'EOS'
set -Eeuo pipefail
SERVER_IP="$1"
TOKEN="$2"
NODE_IP="$3"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  INSTALL_K3S_EXEC="agent --node-ip ${NODE_IP} --with-node-id" \
  sh -s -

systemctl enable --now k3s-agent
EOS
  done
}

write_kubeconfig_to_host() {
  local server_ip="192.168.200.${CONTROL_PLANE_ID}"
  local out="/root/paulina-k3s.yaml"

  log "Writing kubeconfig to ${out}..."
  pct exec "${CONTROL_PLANE_ID}" -- bash -lc 'cat /etc/rancher/k3s/k3s.yaml' |
    sed "s/127.0.0.1/${server_ip}/g" >"${out}"

  chmod 600 "${out}"
  log "Done. Try: export KUBECONFIG=${out} && kubectl get nodes"
}

require_root
require_commands

TEMPLATE_STORAGE="$(pick_template_storage)"
TEMPLATE="$(ensure_debian_template)"

for id in "${CONTROL_PLANE_ID}" "${WORKER_IDS[@]}"; do
  if pct status "${id}" >/dev/null 2>&1; then
    echo "ERROR: CT ${id} already exists. Aborting." >&2
    exit 1
  fi
done

prepare_host_kernel

for id in "${CONTROL_PLANE_ID}" "${WORKER_IDS[@]}"; do
  create_container "${id}"
done

for id in "${CONTROL_PLANE_ID}" "${WORKER_IDS[@]}"; do
  start_container "${id}"
  wait_for_container "${id}"
done

for id in "${CONTROL_PLANE_ID}" "${WORKER_IDS[@]}"; do
  provision_container "${id}"
done

install_k3s_control_plane
install_k3s_workers
write_kubeconfig_to_host

log "All done. 😎😎😎"
```

### 5. Bonus: Riv ner allt (nuke from orbit)

Om jag bara vill stänga av:

```bash
pct stop 241
pct stop 242
pct stop 243
```

Om jag vill radera klustret helt (inkl. rootfs):

```bash
pct stop 241 || true
pct stop 242 || true
pct stop 243 || true

pct destroy 241 --purge 1 || true
pct destroy 242 --purge 1 || true
pct destroy 243 --purge 1 || true
```

Städa bort kubeconfig på hosten:

```bash
rm -f /root/paulina-k3s.yaml
# rm -f ~/.kube/config # obs farligt
```

Om jag inte vill trasha min “riktiga” kubeconfig i `~/.kube/config`, ta bara bort den raden och lämna `/root/paulina-k3s.yaml`.

----

God natt.
