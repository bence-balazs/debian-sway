#!/bin/bash
set -x

if [ $# -eq 0 ]
  then
    echo "No arguments supplied."
    echo "Must use [initialSetup], [package]."
    exit 0
fi

setup_extra_repos() {
  # add contrib, non-free repo
  echo 'deb http://deb.debian.org/debian/ bookworm main non-free-firmware contrib non-free' > /etc/apt/sources.list
  echo 'deb-src http://deb.debian.org/debian/ bookworm main non-free-firmware contrib non-free' >> /etc/apt/sources.list
  echo 'deb http://security.debian.org/debian-security bookworm-security main non-free-firmware' >> /etc/apt/sources.list
  echo 'deb-src http://security.debian.org/debian-security bookworm-security main non-free-firmware' >> /etc/apt/sources.list
  echo 'deb http://deb.debian.org/debian/ bookworm-updates main non-free-firmware contrib non-free' >> /etc/apt/sources.list
  echo 'deb-src http://deb.debian.org/debian/ bookworm-updates main non-free-firmware contrib non-free' >> /etc/apt/sources.list
}

update_upgrade() {
  apt update && apt upgrade -y
}

install_packages() {
  # install neccessary packages
  apt update
  apt install -y $(cat packages.txt)
}


install_fonts() {
  # setup extra fonts
  NF_VERSION="v3.0.1"
  FONTS="FiraCode VictorMono RobotoMono CascadiaCode"
  INSTALL_DIR="/usr/share/fonts"

  mkdir -p $INSTALL_DIR

  for FONT in $FONTS
  do
    wget "https://github.com/ryanoasis/nerd-fonts/releases/download/$NF_VERSION/$FONT.zip"
    unzip "$FONT.zip" -d "$INSTALL_DIR/${FONT}-NerdFont"
    rm "$FONT.zip"
  done
}

setup_vscodium() {
  # setup vscodium
  wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
      | gpg --dearmor \
      | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg

  echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
      | sudo tee /etc/apt/sources.list.d/vscodium.list

  sudo apt update && sudo apt install codium
}

setup_terraform() {
  # setup terraform
  wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  tee /etc/apt/sources.list.d/hashicorp.list

  apt update
  apt install -y terraform
}

setup_docker() {
  # setup docker
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  usermod -aG docker ${LOCAL_USERNAME}
  systemctl enable docker.service
  systemctl enable containerd.service
}

setup_golang() {
  # setup golang
  echo '# GOLANG PATH' >> /etc/profile
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile

  wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
  rm -rf /usr/local/go && tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz
  rm -rf go1.23.2.linux-amd64.tar.gz
}

setup_sshs() {
  # setup sshs
  wget https://github.com/quantumsheep/sshs/releases/download/4.5.1/sshs-linux-amd64.deb
  apt install -y ./sshs-linux-amd64.deb
  rm -rf sshs-linux-amd64.deb
}

setup_virt() {
  # setup virt-manager
  systemctl enable libvirtd
  adduser ${LOCAL_USERNAME} libvirt
  adduser ${LOCAL_USERNAME} kvm
}

setup_sudoers() {
  # add local user to sudoers
  usermod -aG sudo ${LOCAL_USERNAME}

  # set sudo timeout
  echo 'Defaults    timestamp_timeout=30' >> /etc/sudoers
}

move_script() {
  # move setup script to /usr/local/bin
  mv debianSway.sh /usr/local/bin/
}

relink_sh() {
  # link /bin/bash to /bin/sh (dash is default in debian)
  rm -rf /bin/sh
  ln -s /bin/bash /bin/sh
}

case "$1" in
    initialSetup)
        echo "starting initial setup..."
        echo -n "Enter username to add groups(docker,kvm,libvirt): "
        read LOCAL_USERNAME
        setup_extra_repos
        update_upgrade
        install_packages
        install_fonts
        relink_sh
        setup_vscodium
        setup_terraform
        setup_docker
        setup_golang
        setup_sshs
        setup_virt
        setup_sudoers
        systemctl reboot
        ;;

    package)
        echo "installing new packages..."
        install_packages
        ;;  
    *)
        echo "Available commands: [initialSetup], [package]"
        ;;  

esac
