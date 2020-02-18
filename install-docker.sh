#!/bin/bash

clear

RED='\033[0;31m'
BOLDRED='\033[1;31m'
GREEN='\033[0;32m'
BOLDGREEN='\033[1;32m'
YELLOW='\033[1;93m'
#BACKGROUND='\e[0;30;41m' # Black text
BACKGROUND='\e[0;39;41m' # White text
NC='\033[0m' # No Color
SECS=$((5))
DISTRIBUTION=$(cat /etc/os-release | grep ID | head -1 | sed 's/[^a-z]//g')
SELINUX=$(cat /etc/selinux/config | awk '/SELINUX/{i++}i==2' | sed  's/[^a-z]//g')

log_out(){
    echo -ne "\n"
	while [ "$SECS" -gt 0 ]; do
        if [[ "$SECS" == 1 ]]; then
            echo -ne "Logging out in $SECS second \033[0K\r"
        else
            echo -ne "Logging out in $SECS seconds \033[0K\r"
        fi
        sleep 1
        : $((SECS--))
    done

    echo -ne "\n\nNot implemented yet. You have to logout manually!"
}

get_latest_release(){
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

disable_firewalld_install_iptables(){
    systemctl stop firewalld         # Stop the FirewallD service
    systemctl disable firewalld      # Disable the FirewallD service to start automatically on system boot
    systemctl mask --now firewalld   # Mask the FirewallD service to prevent it from being started by another services

    yum install -y iptables-services # Install the iptables-services package
    systemctl start iptables         # Start the Iptables service
    systemctl enable iptables        # Enable the Iptables service to start automatically on system boot
}

permissive_selinux(){
    setenforce permissive
    sed -i "s/SELINUX=${SELINUX}/SELINUX=permissive/g" /etc/selinux/config /etc/selinux/config
    remove_scripts
    # while [ "$SECS" -gt 0 ]; do
    #     if [[ "$SECS" == 1 ]]; then
    #         echo -ne "Rebooting system in $SECS second \033[0K\r"
    #     else
    #         echo -ne "Rebooting system in $SECS seconds \033[0K\r"
    #     fi
    #     sleep 1
    #     : $((SECS--))
    # done
}

remove_scripts(){
    rm get-docker.sh
    rm install-docker.sh
}

echo -ne "\nChecking if running with root user                                             [ ]"\\r
sleep 3

# Check if the script is being run by the root user
if ((EUID)); then
    echo -ne "Checking if running with root user                                             [ ${RED}FAIL${NC} ]"\\r
    sleep 1
    echo -ne "\n\n${BACKGROUND}          You must run this script as root! Exiting...          ${NC}\n\n"
    rm docker-autocomplete.sh
    exit 1
fi
echo -ne "Checking if running with root user                                             [ ${BOLDGREEN}OK${NC} ]"\\r
echo -ne "\n\n"
sleep 1

# Get the script to install Docker
read -rp "Do you want to install Docker? (Y/N) " yn
    case $yn in
        [Yy] ) echo "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh;;
        [Nn] ) echo "Moving on...";;
        * ) echo "Please type "Y" or "N", finalizing script..."
            exit;;
    esac

# Check which distribution is running and install bash-completion
if command -v yum | awk '{print $NF}' | grep -q 'yum'; then
    echo -ne "\n\n${GREEN}"
    yum -y install bash-completion
    systemctl start docker
    systemctl enable docker
elif command -v apt-get | awk '{print $NF}' | grep -q 'apt-get'; then
    echo -ne "\n\n${GREEN}"
    apt-get update -y
    apt-get install -y bash-completion
    echo -ne "\n${BOLDRED}"
    apt-get autoremove -y
else
    echo -ne "\n\n${RED}Neither 'yum' nor 'apt-get' found! Exiting...${NC}\n\n"
    exit 127
fi

# Get Docker Compose version
version=$(get_latest_release docker/compose)

# Install Docker Compose
echo -ne "\n${YELLOW}"
curl -L "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Download docker and docker-compose autocompletion
echo -ne "\n"
curl -L https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker.sh
echo -ne "\n"
curl -L "https://raw.githubusercontent.com/docker/compose/${version}/contrib/completion/bash/docker-compose" -o /etc/bash_completion.d/docker-compose

echo -ne "\n\n${BACKGROUND}          You must logout and login again for the changes to take effect!          ${NC}\n\n\n"

# Disable SELinux
if [[ "$DISTRIBUTION" = "centos" ]]; then
    disable_firewalld_install_iptables
    read -rp "Do you want to set SELinux permissive? (Y/N) " yn
        case $yn in
            [Yy] ) permissive_selinux;;
            [Nn] ) echo "Don't forget to set it later... Finalizing script";;
            * ) echo "Please type "Y" or "N", finalizing script..."
                remove_scripts && exit;;
        esac
fi
echo -ne "\n\n"
