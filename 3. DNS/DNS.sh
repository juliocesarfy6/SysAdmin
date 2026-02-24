#!/usr/bin/env bash
set -euo pipefail

DOMAIN_DEFAULT="reprobados.com"
ZONEFILE_DEFAULT="/var/cache/bind/db.reprobados.com"
NAMED_LOCAL="/etc/bind/named.conf.local"
NAMED_OPTIONS="/etc/bind/named.conf.options"

log(){ echo -e "[INFO] $*"; }
warn(){ echo -e "[WARN] $*" >&2; }
err(){ echo -e "[ERROR] $*" >&2; exit 1; }

need_root(){
  if [[ $EUID -ne 0 ]]; then
    err "Ejecuta como root: sudo $0 ..."
  fi
}

has_static_ip_netplan(){
  local f
  for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [[ -f "$f" ]] || continue
    if grep -qE "dhcp4:\s*no" "$f" && grep -qE "addresses:" "$f"; then
      return 0
    fi
  done
  return 1
}

detect_iface(){
  ip -o link show | awk -F': ' '{print $2}' | grep -vE 'lo' | head -n 1
}

configure_static_ip_netplan(){
  local iface="$1"
  local ipcidr="$2"
  local gw="$3"
  local dns="$4"
  local outfile="/etc/netplan/01-dns-static.yaml"

  cat > "$outfile" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $iface:
      dhcp4: no
      addresses:
        - $ipcidr
      routes:
        - to: default
          via: $gw
      nameservers:
        addresses: [$dns]
EOF

  netplan generate
  netplan apply
}

bind_installed(){
  dpkg -s bind9 >/dev/null 2>&1
}

bind_running(){
  systemctl is-active --quiet bind9
}

install_bind(){
  apt-get update -y
  apt-get install -y bind9 bind9utils bind9-doc
}

ensure_bind_options(){
  if ! grep -q "listen-on { any; };" "$NAMED_OPTIONS"; then
    sed -i 's/listen-on-v6 { any; };/listen-on { any; };\n\tlisten-on-v6 { any; };/' "$NAMED_OPTIONS" || true
  fi
  if ! grep -q "allow-query { any; };" "$NAMED_OPTIONS"; then
    sed -i 's/options {/options {\n\tallow-query { any; };/' "$NAMED_OPTIONS" || true
  fi
}

ensure_named_conf_local_zone(){
  local domain="$1"
  local zonefile="$2"

  if grep -qE "zone \"${domain}\"" "$NAMED_LOCAL" 2>/dev/null; then
    return
  fi

  cat >> "$NAMED_LOCAL" <<EOF

zone "${domain}" {
  type master;
  file "${zonefile}";
};
EOF
}

increment_serial_yyyymmddnn(){
  local old="$1"
  local today
  today="$(date +%Y%m%d)"
  if [[ "$old" =~ ^${today}([0-9]{2})$ ]]; then
    local nn="${BASH_REMATCH[1]}"
    local newnn
    newnn=$(printf "%02d" $((10#$nn + 1)))
    echo "${today}${newnn}"
  else
    echo "${today}01"
  fi
}

ensure_zonefile(){
  local domain="$1"
  local zonefile="$2"
  local target_ip="$3"
  local use_cname="$4"

  mkdir -p "$(dirname "$zonefile")"

  if [[ ! -f "$zonefile" ]]; then
    cat > "$zonefile" <<EOF
\$TTL 604800
@   IN  SOA ns1.${domain}. admin.${domain}. (
        2026010101 ; Serial
        604800
        86400
        2419200
        604800 )
@       IN  NS      ns1.${domain}.
ns1     IN  A       127.0.0.1
@       IN  A       ${target_ip}
EOF
  fi

  local current_serial
  current_serial="$(awk '/Serial/{print $1; exit}' "$zonefile" || true)"
  if [[ -n "$current_serial" ]]; then
    local new_serial
    new_serial="$(increment_serial_yyyymmddnn "$current_serial")"
    sed -i "0,/^[0-9]\{10\}[[:space:]]*; Serial/s//${new_serial} ; Serial/" "$zonefile" || true
  fi

  sed -i "0,/^[[:space:]]*@\?[[:space:]]\+IN[[:space:]]\+A.*/s//@       IN  A   ${target_ip}/" "$zonefile" || true

  if [[ "$use_cname" == "true" ]]; then
    sed -i "/^www[[:space:]].*IN[[:space:]]\+A/d" "$zonefile"
    if grep -qE "^www[[:space:]].*IN[[:space:]]+CNAME" "$zonefile"; then
      sed -i "0,/^www[[:space:]].*IN[[:space:]]\+CNAME.*/s//www     IN  CNAME   @/" "$zonefile"
    else
      echo "www     IN  CNAME   @" >> "$zonefile"
    fi
  else
    sed -i "/^www[[:space:]].*IN[[:space:]]\+CNAME/d" "$zonefile"
    if grep -qE "^www[[:space:]].*IN[[:space:]]+A" "$zonefile"; then
      sed -i "0,/^www[[:space:]].*IN[[:space:]]\+A.*/s//www     IN  A       ${target_ip}/" "$zonefile"
    else
      echo "www     IN  A       ${target_ip}" >> "$zonefile"
    fi
  fi
}

validate_bind(){
  named-checkconf
  named-checkzone "$domain" "$zonefile"
}

restart_bind(){
  systemctl enable --now bind9
  systemctl restart bind9
}

usage(){
  echo "Uso:"
  echo "sudo $0 --target-ip 192.168.X.X --server-ip 192.168.X.X"
}

main(){
  need_root

  local domain="$DOMAIN_DEFAULT"
  local zonefile="$ZONEFILE_DEFAULT"
  local target_ip=""
  local server_ip=""
  local use_cname="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) domain="$2"; shift 2;;
      --target-ip) target_ip="$2"; shift 2;;
      --server-ip) server_ip="$2"; shift 2;;
      --use-cname) use_cname="$2"; shift 2;;
      -h|--help) usage; exit 0;;
      *) err "Argumento desconocido: $1";;
    esac
  done

  [[ -n "$target_ip" ]] || err "Falta --target-ip"
  [[ -n "$server_ip" ]] || err "Falta --server-ip"

  if ! has_static_ip_netplan; then
    iface="$(detect_iface)"
    read -r -p "IP/CIDR servidor: " ipcidr
    read -r -p "Gateway: " gw
    read -r -p "DNS upstream: " dns
    configure_static_ip_netplan "$iface" "$ipcidr" "$gw" "$dns"
  fi

  bind_installed || install_bind
  ensure_bind_options
  ensure_named_conf_local_zone "$domain" "$zonefile"
  ensure_zonefile "$domain" "$zonefile" "$target_ip" "$use_cname"
  validate_bind
  restart_bind

  echo "Dominio ${domain} configurado apuntando a ${target_ip}"
}

main "$@"
