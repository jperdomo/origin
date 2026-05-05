#!/usr/bin/env bash
# make-vm.sh — create an unattended Ubuntu 26.04 or Windows 11 Pro VM via libvirt.
#   Ubuntu uses cloud-init NoCloud seed; Windows uses Mido + autounattend.xml.
# Usage:   make-vm.sh [-y|--yes] [--server|--desktop|--windows] [--rdp|--no-rdp]
#                    [--passwordless-sudo] [--user NAME] [--memory MB] [--vcpus N]
#                    [--disk GB] [--keep-cdrom] [--iso PATH] [VM_NAME]
# Default: interactive — prompts for every setting (any flags become prefilled defaults).
#   server:  2 vCPU, 4 GiB RAM, 40 GiB disk, user = $USER
#   desktop: 2 vCPU, 4 GiB RAM, 40 GiB disk, user = $USER
#   windows: 6 vCPU, 8 GiB RAM, 80 GiB disk, user = $USER
# --rdp: enable RDP on :3389 (default ON for windows, OFF otherwise).
#   desktop: installs gnome-remote-desktop with same user/pass.
#   windows: enables fDenyTSConnections=0 + firewall rule via autounattend.
# --passwordless-sudo: Ubuntu only — grants NOPASSWD sudo (off by default).
# --keep-cdrom: skip the post-install CDROM-detach watcher.
# After install, watcher detaches install/seed CDROMs, deletes seed ISO, restarts VM.
# Watcher log: $XDG_STATE_HOME/make-vm/<name>-cleanup.log
# -y skips prompts (requires VM_NAME on cmdline; password from MAKEVM_PASSWORD env).
# Windows ISO: pass --iso PATH or accept the autosuggested path at the interactive
#   prompt (most recent ~/Downloads/Win11*.iso). Leave the prompt blank to auto-fetch
#   Windows 11 Pro English (US) x64 via Fido (https://github.com/pbatard/Fido) — installs
#   the powershell snap on demand. Copied into /var/lib/libvirt/images/win11x64.iso.
#   virtio-win.iso is auto-fetched from fedorapeople.org.

set -euo pipefail

VARIANT=server
USERNAME=$USER
MEM_MB=4096
VCPUS=2
DISK_GB=40
NAME=
INTERACTIVE=1
RDP=0
KEEP_CDROM=0
PASSWORDLESS_SUDO=0
IMG_DIR=/var/lib/libvirt/images
ISO_OVERRIDE=
MEM_EXPLICIT=0
VCPU_EXPLICIT=0
DISK_EXPLICIT=0
RDP_EXPLICIT=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes|--non-interactive) INTERACTIVE=0; shift;;
        -i|--interactive) INTERACTIVE=1; shift;;
        --desktop) VARIANT=desktop; shift;;
        --server)  VARIANT=server;  shift;;
        --windows) VARIANT=windows; shift;;
        --rdp)     RDP=1; RDP_EXPLICIT=1; shift;;
        --no-rdp)  RDP=0; RDP_EXPLICIT=1; shift;;
        --keep-cdrom) KEEP_CDROM=1; shift;;
        --passwordless-sudo) PASSWORDLESS_SUDO=1; shift;;
        --user)    USERNAME=$2; shift 2;;
        --memory)  MEM_MB=$2;   MEM_EXPLICIT=1;  shift 2;;
        --vcpus)   VCPUS=$2;    VCPU_EXPLICIT=1; shift 2;;
        --disk)    DISK_GB=$2;  DISK_EXPLICIT=1; shift 2;;
        --iso)     ISO_OVERRIDE=$2; shift 2;;
        -h|--help) sed -n '2,24p' "$0" | sed 's/^# \?//'; exit 0;;
        -*)        echo "unknown flag: $1" >&2; exit 2;;
        *)         NAME=$1; shift;;
    esac
done

[[ -t 0 ]] || INTERACTIVE=0

if [[ $VARIANT == windows ]]; then
    (( VCPU_EXPLICIT )) || VCPUS=6
    (( MEM_EXPLICIT  )) || MEM_MB=8192
    (( DISK_EXPLICIT )) || DISK_GB=80
    (( RDP_EXPLICIT  )) || RDP=1
fi

ask() {
    local var=$1 def=$2 msg=$3 val
    read -rp "$msg [$def]: " val
    printf -v "$var" '%s' "${val:-$def}"
}

ask_yn() {
    local var=$1 def=$2 msg=$3 val def_label
    [[ $def == 1 ]] && def_label=Y/n || def_label=y/N
    read -rp "$msg [$def_label]: " val
    val=${val:-$([[ $def == 1 ]] && echo y || echo n)}
    case $val in
        y|Y|yes|YES|1) printf -v "$var" '%s' 1;;
        *)             printf -v "$var" '%s' 0;;
    esac
}

if (( INTERACTIVE )); then
    while :; do
        ask VARIANT  "$VARIANT"  "Variant (server/desktop/windows)"
        [[ $VARIANT == server || $VARIANT == desktop || $VARIANT == windows ]] && break
        echo "  must be 'server', 'desktop', or 'windows'"
    done
    while :; do
        ask NAME "$NAME" "VM name"
        [[ -n $NAME ]] && break
        echo "  required"
    done
    ask USERNAME "$USERNAME" "Username"
    ask VCPUS    "$VCPUS"    "vCPUs"
    ask MEM_MB   "$MEM_MB"   "Memory (MiB)"
    ask DISK_GB  "$DISK_GB"  "Disk (GiB)"
    if [[ $VARIANT == windows && -z $ISO_OVERRIDE ]]; then
        ISO_DEFAULT=$(ls -t "$HOME"/Downloads/Win11*.iso 2>/dev/null | head -1)
        while :; do
            ask ISO_OVERRIDE "$ISO_DEFAULT" "Win11 ISO path (blank = fetch Win11 Pro English US via Fido)"
            [[ -z $ISO_OVERRIDE ]] && break
            ISO_OVERRIDE="${ISO_OVERRIDE/#\~/$HOME}"
            [[ -r $ISO_OVERRIDE ]] && break
            echo "  not readable: $ISO_OVERRIDE"
        done
    fi
    if [[ $VARIANT == desktop ]]; then
        ask_yn RDP "$RDP" "Enable Remote Login (RDP on :3389, same creds as user)?"
    elif [[ $VARIANT == windows ]]; then
        ask_yn RDP "$RDP" "Enable RDP on :3389 (same creds as user)?"
    fi
fi

if (( RDP )) && [[ $VARIANT == server ]]; then
    echo "--rdp not valid with --server; ignoring" >&2
    RDP=0
fi

[[ -n $NAME ]] || { echo "VM_NAME required (or use -i)" >&2; exit 2; }
[[ $NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$ ]] || { echo "VM_NAME must match ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}\$ (got: $NAME)" >&2; exit 2; }
[[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}\$?$ ]] || { echo "USERNAME must be a valid POSIX user name (got: $USERNAME)" >&2; exit 2; }

case $VARIANT in
    server)  ISO_NAME=ubuntu-26.04-live-server-amd64.iso;;
    desktop) ISO_NAME=ubuntu-26.04-desktop-amd64.iso;;
    windows) ISO_NAME=win11x64.iso;;
esac
ISO=$IMG_DIR/$ISO_NAME
VIRTIO_ISO=$IMG_DIR/virtio-win.iso

if [[ -n $ISO_OVERRIDE ]]; then
    [[ -r $ISO_OVERRIDE ]] || { echo "--iso path not readable: $ISO_OVERRIDE" >&2; exit 1; }
    if [[ $(realpath -- "$ISO_OVERRIDE") != "$(realpath -m -- "$ISO")" ]]; then
        echo "Installing $ISO_OVERRIDE -> $ISO (libvirt needs the ISO under $IMG_DIR)..."
        sudo install -d -m 0711 "$IMG_DIR"
        sudo install -m 0644 "$ISO_OVERRIDE" "$ISO"
    fi
fi

if [[ $VARIANT != windows ]]; then
    if [[ ! -r $ISO ]]; then
        DL=1
        (( INTERACTIVE )) && ask_yn DL 1 "ISO not found at $ISO. Download from releases.ubuntu.com (~5 GB)?"
        (( DL )) || { echo "ISO not readable: $ISO" >&2; exit 1; }
        command -v curl >/dev/null || { echo "curl required to fetch ISO" >&2; exit 1; }
        URL=https://releases.ubuntu.com/26.04/$ISO_NAME
        echo "Downloading $ISO_NAME (sudo needed to write to $IMG_DIR)..."
        sudo install -d -m 0711 "$IMG_DIR"
        sudo curl -fL --retry 3 -o "$ISO" "$URL"
        sudo chmod 0644 "$ISO"
        if SUMS=$(curl -fsSL "https://releases.ubuntu.com/26.04/SHA256SUMS"); then
            EXPECTED=$(printf '%s\n' "$SUMS" | grep -F "$ISO_NAME" | awk '{print $1; exit}')
            if [[ -n $EXPECTED ]]; then
                ACTUAL=$(sha256sum "$ISO" | awk '{print $1}')
                [[ $ACTUAL == "$EXPECTED" ]] || { echo "checksum mismatch for $ISO" >&2; sudo rm -f "$ISO"; exit 1; }
                echo "checksum verified"
            else
                echo "warning: $ISO_NAME not in SHA256SUMS — skipping verify" >&2
            fi
        else
            echo "warning: could not fetch SHA256SUMS — skipping verify" >&2
        fi
    fi
else
    if [[ ! -r $ISO ]]; then
        DL=1
        (( INTERACTIVE )) && ask_yn DL 1 "Win11 Pro English (US) ISO not found at $ISO. Fetch via Fido (~5 GB; installs pwsh snap if needed)?"
        (( DL )) || {
            echo "ISO not readable: $ISO" >&2
            echo "Download from https://www.microsoft.com/software-download/windows11" >&2
            echo "and re-run with --iso /path/to/Win11_*.iso" >&2
            exit 1
        }
        command -v curl >/dev/null || { echo "curl required to fetch Fido + ISO" >&2; exit 1; }
        if ! command -v pwsh >/dev/null; then
            command -v snap >/dev/null || {
                echo "pwsh and snap both missing; can't auto-fetch. Install pwsh and retry." >&2
                exit 1
            }
            echo "Installing PowerShell via snap (one-time, ~80 MB)..."
            sudo snap install powershell --classic || { echo "snap install powershell failed" >&2; exit 1; }
        fi
        sudo install -d -m 0711 "$IMG_DIR"
        FIDO_DIR=$(mktemp -d)
        echo "Fetching Fido and resolving Win11 Pro English (US) x64 download URL..."
        curl -fsSL -o "$FIDO_DIR/Fido.ps1" \
            https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1
        # Fido is Windows-targeted; spoof Get-Platform-Version to bypass the
        # "non Windows platforms are too much of a liability" gate (line ~73).
        # -PlatformArch x64 separately bypasses Get-CimInstance (Windows-only WMI).
        sed -i 's|^\(\s*\)\$version = 0\.0|\1$version = 10.0|' "$FIDO_DIR/Fido.ps1"
        # -Lang takes an unanchored regex; "^English$" pins to US English (not "English International")
        FIDO_URL=$(pwsh -NoProfile -File "$FIDO_DIR/Fido.ps1" \
            -Win 11 -Ed Pro -Lang '^English$' -Arch x64 -PlatformArch x64 -GetUrl 2>&1 | grep -E '^https?://' | tail -1)
        rm -rf "$FIDO_DIR"
        if [[ -z $FIDO_URL || $FIDO_URL != http* ]]; then
            echo "Fido failed to resolve a download URL (Microsoft may have rotated their gated endpoint)." >&2
            echo "Download manually from https://www.microsoft.com/software-download/windows11" >&2
            echo "and re-run with --iso /path/to/Win11_*.iso" >&2
            exit 1
        fi
        echo "Downloading ISO from Microsoft (URL valid ~24h)..."
        sudo curl -fL --retry 3 -o "$ISO" "$FIDO_URL"
        sudo chmod 0644 "$ISO"
    fi
    if [[ ! -r $VIRTIO_ISO ]]; then
        echo "Downloading virtio-win.iso..."
        sudo install -d -m 0711 "$IMG_DIR"
        sudo curl -fL --retry 3 -o "$VIRTIO_ISO" \
            https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
        sudo chmod 0644 "$VIRTIO_ISO"
        echo "warning: virtio-win.iso has no published SHA256SUMS — skipping verify" >&2
    fi
fi

[[ -r $ISO ]] || { echo "ISO not readable: $ISO" >&2; exit 1; }

declare -A PKG_FOR=([mkpasswd]=whois [cloud-localds]=cloud-image-utils [virt-install]=virtinst [genisoimage]=genisoimage)
missing=()
for t in mkpasswd cloud-localds virt-install genisoimage; do
    command -v "$t" >/dev/null || missing+=("$t")
done
if [[ $VARIANT == windows ]]; then
    PKG_FOR[swtpm]=swtpm
    PKG_FOR[swtpm_setup]=swtpm-tools
    for t in swtpm swtpm_setup; do
        command -v "$t" >/dev/null || missing+=("$t")
    done
    if [[ ! -e /usr/share/OVMF/OVMF_VARS_4M.ms.fd ]]; then
        missing+=(_ovmf)
        PKG_FOR[_ovmf]=ovmf
    fi
fi
if (( ${#missing[@]} )); then
    pkgs=()
    for t in "${missing[@]}"; do pkgs+=("${PKG_FOR[$t]}"); done
    echo "installing missing tools (${missing[*]}) via sudo apt: ${pkgs[*]}"
    sudo apt-get install -y "${pkgs[@]}"
fi

if [[ -n ${MAKEVM_PASSWORD:-} ]]; then
    PW=$MAKEVM_PASSWORD
else
    read -rsp "Password for $USERNAME on $NAME: " PW; echo
    read -rsp "Confirm: " PW2; echo
    [[ $PW == "$PW2" ]] || { echo "passwords do not match" >&2; exit 1; }
    unset PW2
fi

if [[ $VARIANT == windows ]]; then
    b64utf16le() { printf '%s' "$1$2" | iconv -f UTF-8 -t UTF-16LE | base64 -w0; }
    PW_USER_B64=$(b64utf16le "$PW" Password)
    PW_XML=${PW//&/&amp;}
    PW_XML=${PW_XML//</&lt;}
    PW_XML=${PW_XML//>/&gt;}
    PW_XML=${PW_XML//\"/&quot;}
    PW_XML=${PW_XML//\'/&apos;}
else
    HASH=$(printf '%s' "$PW" | mkpasswd -m sha-512 -s)
fi

if (( RDP )) && [[ $VARIANT == desktop ]]; then
    case $PW in
        *\'*) echo "RDP setup can't handle ' in passwords; choose another or skip --rdp" >&2; exit 1;;
    esac
fi

WORK=$(mktemp -d)
cleanup() {
    local rc=$?
    rm -rf "$WORK"
    if (( rc != 0 )) && [[ -n ${SEED:-} && -f $SEED ]]; then
        rm -f "$SEED"
    fi
}
trap cleanup EXIT

SEED_DIR=$IMG_DIR/seeds
if [[ ! -w $SEED_DIR ]]; then
    sudo install -d -o "$USER" -m 0755 "$SEED_DIR"
fi
SEED=$SEED_DIR/seed-$NAME.iso
# Stale seed from a prior aborted run may be owned by root (libvirt dynamic_ownership);
# remove it with sudo so genisoimage/cloud-localds can recreate it.
[[ -e $SEED && ! -w $SEED ]] && sudo rm -f "$SEED"

if [[ $VARIANT != windows ]]; then
    cat > "$WORK/meta-data" <<EOF
instance-id: iid-$NAME
local-hostname: $NAME
EOF

    {
    cat <<EOF
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  identity:
    hostname: $NAME
    realname: $USERNAME
    username: $USERNAME
    password: "$HASH"
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - qemu-guest-agent
    - openssh-server
    - git
EOF
    (( RDP )) && echo "    - gnome-remote-desktop"
    (( KEEP_CDROM )) || echo "  shutdown: poweroff"
    cat <<EOF
  late-commands:
EOF
    if (( PASSWORDLESS_SUDO )); then
    cat <<EOF
    - "echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/90-$USERNAME"
    - "chmod 440 /target/etc/sudoers.d/90-$USERNAME"
EOF
    fi
    if (( RDP )); then
    cat <<EOF
    - "curtin in-target --target=/target -- install -d -m 750 -o gnome-remote-desktop -g gnome-remote-desktop /etc/gnome-remote-desktop"
    - "curtin in-target --target=/target -- openssl req -x509 -newkey rsa:4096 -nodes -keyout /etc/gnome-remote-desktop/rdp-tls.key -out /etc/gnome-remote-desktop/rdp-tls.crt -subj '/CN=$NAME' -days 3650"
    - "curtin in-target --target=/target -- chown gnome-remote-desktop:gnome-remote-desktop /etc/gnome-remote-desktop/rdp-tls.crt /etc/gnome-remote-desktop/rdp-tls.key"
    - "curtin in-target --target=/target -- chmod 640 /etc/gnome-remote-desktop/rdp-tls.crt /etc/gnome-remote-desktop/rdp-tls.key"
    - "curtin in-target --target=/target -- grdctl --system rdp set-tls-cert /etc/gnome-remote-desktop/rdp-tls.crt"
    - "curtin in-target --target=/target -- grdctl --system rdp set-tls-key /etc/gnome-remote-desktop/rdp-tls.key"
    - "curtin in-target --target=/target -- grdctl --system rdp set-credentials '$USERNAME' '$PW'"
    - "curtin in-target --target=/target -- grdctl --system rdp enable"
    - "curtin in-target --target=/target -- systemctl enable gnome-remote-desktop.service"
    - "curtin in-target --target=/target -- bash -c 'rm -f /var/log/installer/autoinstall-user-data /var/lib/cloud/instance/user-data.txt /var/lib/cloud/instance/user-data.txt.i; rm -rf /var/lib/cloud/seed /var/lib/cloud/seeds; for f in /var/log/installer/*.log /var/log/cloud-init.log /var/log/cloud-init-output.log; do [ -f \"\$f\" ] && : > \"\$f\"; done; journalctl --rotate; journalctl --vacuum-time=1s'"
EOF
    fi
    cat <<EOF
    - "curtin in-target --target=/target -- runuser -u $USERNAME -- git clone https://github.com/jperdomo/origin.git /home/$USERNAME/origin"
EOF
    } > "$WORK/user-data"
    cloud-localds "$SEED" "$WORK/user-data" "$WORK/meta-data"
else
    if (( RDP )); then
        RDP_DENY_VAL=false
        RDP_ACTIVE_VAL=true
    else
        RDP_DENY_VAL=true
        RDP_ACTIVE_VAL=false
    fi
    cat > "$WORK/autounattend.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>0409:00000409</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>300</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <Value>Windows 11 Pro</Value>
            </MetaData>
          </InstallFrom>
          <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>$USERNAME</FullName>
        <Organization></Organization>
        <ProductKey>
          <Key>W269N-WFGWX-YVC9B-4J6C9-T83GX</Key>
          <WillShowUI>Never</WillShowUI>
        </ProductKey>
      </UserData>
      <DynamicUpdate><Enable>false</Enable><WillShowUI>Never</WillShowUI></DynamicUpdate>
    </component>
    <component name="Microsoft-Windows-PnpCustomizationsWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <DriverPaths>
        <PathAndCredentials wcm:action="add" wcm:keyValue="1"><Path>D:\viostor\w11\amd64</Path></PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="2"><Path>E:\viostor\w11\amd64</Path></PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="3"><Path>F:\viostor\w11\amd64</Path></PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="4"><Path>D:\NetKVM\w11\amd64</Path></PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="5"><Path>E:\NetKVM\w11\amd64</Path></PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="6"><Path>F:\NetKVM\w11\amd64</Path></PathAndCredentials>
      </DriverPaths>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$NAME</ComputerName>
      <TimeZone>Coordinated Universal Time</TimeZone>
    </component>
    <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <fDenyTSConnections>$RDP_DENY_VAL</fDenyTSConnections>
    </component>
    <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <FirewallGroups>
        <FirewallGroup wcm:action="add" wcm:keyValue="rdp">
          <Active>$RDP_ACTIVE_VAL</Active>
          <Group>@FirewallAPI.dll,-28752</Group>
          <Profile>all</Profile>
        </FirewallGroup>
      </FirewallGroups>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>0409:00000409</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Other</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>$USERNAME</Name>
            <Group>Administrators</Group>
            <DisplayName>$USERNAME</DisplayName>
            <Password>
              <Value>$PW_USER_B64</Value>
              <PlainText>false</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Username>$USERNAME</Username>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Password>
          <Value>$PW_USER_B64</Value>
          <PlainText>false</PlainText>
        </Password>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Wait for winget</Description>
          <CommandLine>cmd.exe /c "for /l %i in (1,1,30) do (where winget &amp;&amp; exit 0) &amp; timeout /t 5 /nobreak"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Install Git</Description>
          <CommandLine>cmd.exe /c "winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements --silent"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Clone origin repo</Description>
          <CommandLine>cmd.exe /c "&quot;C:\Program Files\Git\bin\git.exe&quot; clone https://github.com/jperdomo/origin.git %USERPROFILE%\origin"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Description>Scrub unattend artifacts and cached AutoLogon password</Description>
          <CommandLine>cmd.exe /c "del /f /q C:\Windows\Panther\unattend.xml C:\Windows\Panther\Unattend\unattend.xml 2&gt;nul &amp; del /f /q C:\Windows\System32\Sysprep\unattend.xml 2&gt;nul &amp; reg delete &quot;HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon&quot; /v DefaultPassword /f 2&gt;nul"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Description>Shutdown to trigger host watcher</Description>
          <CommandLine>cmd.exe /c "shutdown /s /t 5 /f"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
EOF
    genisoimage -V WINSEED -J -joliet-long -r -o "$SEED" "$WORK/autounattend.xml"
    chmod 0600 "$SEED"
fi
unset PW

case $VARIANT in
    desktop) GRAPHICS=(--graphics spice --graphics vnc,listen=127.0.0.1 --video qxl);;
    server)  GRAPHICS=(--graphics vnc,listen=127.0.0.1 --video virtio);;
    windows) GRAPHICS=(--graphics spice,listen=127.0.0.1 --graphics vnc,listen=127.0.0.1 --video qxl);;
esac

if [[ $VARIANT == windows ]]; then
    virt-install \
        --connect qemu:///system \
        --name "$NAME" \
        --memory "$MEM_MB" \
        --vcpus "$VCPUS" \
        --cpu host-passthrough \
        --machine q35 \
        --osinfo win11 \
        --features smm.state=on \
        --boot cdrom,hd,firmware=efi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=yes \
        --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
        --disk "size=$DISK_GB,format=qcow2,bus=virtio,discard=unmap" \
        --disk "path=$ISO,device=cdrom,bus=sata,readonly=on" \
        --disk "path=$VIRTIO_ISO,device=cdrom,bus=sata,readonly=on" \
        --disk "path=$SEED,device=cdrom,bus=sata,readonly=on" \
        --network network=default,model=virtio \
        --sound ich9 \
        --controller type=usb,model=qemu-xhci \
        --rng /dev/urandom \
        --noautoconsole \
        "${GRAPHICS[@]}"
else
    virt-install \
        --connect qemu:///system \
        --name "$NAME" \
        --memory "$MEM_MB" \
        --vcpus "$VCPUS" \
        --disk "size=$DISK_GB,format=qcow2" \
        --disk "path=$SEED,device=cdrom" \
        --location "$ISO,kernel=casper/vmlinuz,initrd=casper/initrd" \
        --extra-args "autoinstall ds=nocloud overlay.index=off overlay.redirect_dir=off overlay.metacopy=off" \
        --osinfo "detect=on,name=ubuntu24.04" \
        --network network=default \
        --noautoconsole \
        "${GRAPHICS[@]}"
fi

if [[ $VARIANT == windows ]]; then
    # Auto-satisfy bootmgfw.efi's "Press any key to boot from CD or DVD" prompt.
    # Send SPACE every second for 90 seconds; misses are harmless no-ops.
    setsid -f bash -c '
        name=$1
        for _ in $(seq 1 90); do
            virsh -c qemu:///system send-key "$name" KEY_SPACE >/dev/null 2>&1 || true
            sleep 1
        done
    ' _ "$NAME" </dev/null >/dev/null 2>&1
fi

if (( ! KEEP_CDROM )); then
    LOG_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/make-vm
    mkdir -p "$LOG_DIR"
    LOG=$LOG_DIR/${NAME}-cleanup.log
    setsid -f bash -c '
        name=$1 seed=$2 log=$3
        exec >>"$log" 2>&1
        echo "[$(date -Is)] watcher started; waiting for $name to power off"
        deadline=$(( $(date +%s) + 7200 ))
        while (( $(date +%s) < deadline )); do
            state=$(virsh -c qemu:///system domstate "$name" 2>/dev/null) || { echo "[$(date -Is)] domain gone"; exit 1; }
            if [[ $state == "shut off" ]]; then
                echo "[$(date -Is)] $name shut off; detaching cdroms"
                while read -r dev; do
                    [[ -z $dev ]] && continue
                    echo "[$(date -Is)] detach $dev"
                    virsh -c qemu:///system detach-disk "$name" "$dev" --config || true
                done < <(virsh -c qemu:///system domblklist "$name" --details | awk "\$2==\"cdrom\"{print \$3}")
                if [[ -f $seed ]]; then
                    rm -f "$seed" && echo "[$(date -Is)] removed seed $seed"
                fi
                echo "[$(date -Is)] starting $name"
                virsh -c qemu:///system start "$name" && echo "[$(date -Is)] done"
                exit 0
            fi
            sleep 10
        done
        echo "[$(date -Is)] timed out (2h) waiting for shut off"
        exit 1
    ' _ "$NAME" "$SEED" "$LOG" </dev/null >/dev/null 2>&1
fi

cat <<EOF

VM "$NAME" is installing. Watch progress in Cockpit (Virtual Machines tab) or:
  virsh -c qemu:///system console $NAME    # serial console (server only)
  virt-viewer --connect qemu:///system $NAME   # graphical (desktop/windows)

After install completes the VM $( (( KEEP_CDROM )) && echo "reboots" || echo "powers off, then a background watcher detaches the CDROMs, deletes the seed ISO, and restarts it" ); log in as: $USERNAME
EOF
(( KEEP_CDROM )) || echo "Watcher log: $LOG"

if (( RDP )) && [[ $VARIANT == desktop ]]; then
cat <<EOF
RDP enabled: connect to <vm-ip>:3389 with username "$USERNAME" and the same password.
  ip:   virsh -c qemu:///system domifaddr $NAME
Guest scrub on install: cloud-init/installer logs truncated, cached user-data deleted,
journal vacuumed.$( (( KEEP_CDROM )) && printf '\nHost seed ISO still contains plaintext — delete it after first boot:\n  rm /var/lib/libvirt/images/seeds/seed-%s.iso' "$NAME" )
EOF
fi

if [[ $VARIANT == windows ]]; then
cat <<EOF
Windows install notes:
  RDP: $( (( RDP )) && echo "enabled — connect to <vm-ip>:3389 as $USERNAME with the same password" || echo "disabled (--no-rdp)" )
  ip:  virsh -c qemu:///system domifaddr $NAME
  Guest log paths (after first boot):
    C:\\Windows\\Panther\\setupact.log              # Setup phases
    C:\\Windows\\Panther\\UnattendGC\\setupact.log  # FirstLogonCommands
  virsh console won't work (no Windows serial); use virt-viewer for graphical access.$( (( KEEP_CDROM )) && printf '\nHost seed ISO still contains plaintext — delete it after first boot:\n  rm /var/lib/libvirt/images/seeds/seed-%s.iso' "$NAME" )
EOF
fi
