#!/usr/bin/env bash
#
# Setup script for Kali pen testing image.
# Adds additional scripts, files, and binaries.

###############################################
# FUNCTIONS
###############################################
curl_get() {
    url=$1
    file=$2
    return_value=0  # assume success unless something happens
    tmp_filename=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 10)
    write_location=$tmp_dir"/"$tmp_filename

    result=$(curl -L -sS --connect-timeout 5 "$url" > $write_location)
    if [ $? -ne 0 ]; then
        echo "[-] Unable to retrieve $url"
        echo "[-] Curl error:"
        echo "$result"
        rm $file
        return_value=1
    else
        sudo mv $write_location $file
    fi

    return $return_value
}

test_command() {
    cmd=$1
    good=$2
    bad=$3

    $cmd

    if [ $? -eq 0 ]; then
        echo "$good"
    else
        echo "$bad"
    fi
}


if [ "$#" -lt 1 ]; then
    echo "Usage: kali_setup.sh <local bin directory>"
    echo "Example: kali_setup.sh /home/user/bin"
    exit 1
fi

random_dir=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 10)
local_bin_dir=$1
utils_dir="/opt/utils"
tmp_dir="/tmp/"$random_dir
current_user=$(whoami)

# make the necessary directories
mkdir ${local_bin_dir}
sudo mkdir -p ${utils_dir}"/downloads"
sudo mkdir ${seclists_dir}
mkdir ${tmp_dir}

# apt packages
echo "[+] Installing apt packages"
sudo apt update && sudo apt install -y crackmapexec openvas libssl-dev ufw seclists

# my scripts
echo "[+] Installing my scripts"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/masscan.sh ${local_bin_dir}"/masscan.sh"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/nmap.sh ${local_bin_dir}"/nmap.sh"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/scan_host_list.py ${local_bin_dir}"/scan_host_list.py"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/false_positive_test.sh ${local_bin_dir}"/false_positive_test.sh"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/pipa-route.sh ${local_bin_dir}"/pipa-route.sh"
curl_get https://raw.githubusercontent.com/jordantrc/enumeration/master/http-security-check.sh ${local_bin_dir}"/http-security-check.sh"
curl_get https://raw.githubusercontent.com/jordantrc/pentesting/master/utils/llog.sh ${local_bin_dir}"/llog"

cd ${local_bin_dir}
chown $USER ./*
chmod +x *.sh
chmod +x llog

# tmux configuration
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
cat <<EOF > ~/.tmux.conf
set -g history-limit 50000

# list of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-logging'

# initialize tmux plugin manager
run '~/.tmux/plugins/tpm/tpm'
EOF

# other people's work
# RDPScan
echo "[+] Installing RDPScan by Robert Graham"
sudo mkdir -p ${utils_dir}"/rdpscan/src"
zip_file_location=${utils_dir}"/downloads/rdpscan.zip"
curl_get https://github.com/robertdavidgraham/rdpscan/archive/master.zip ${zip_file_location}
# unzip to src directory
sudo unzip ${zip_file_location} -d ${utils_dir}"/rdpscan/src"
cd ${utils_dir}"/rdpscan/src/rdpscan-master"
sudo make
test_command "sudo mv rdpscan ../../" "[+] RDPscan installation complete" "[-] RDPscan installation failed"

# krbGuess
echo "[+] Installing KrbGuess"
curl_get https://www.cqure.net/tools/krbguess-0.21-bin.tar.gz ${utils_dir}"/downloads/krbguess.tar.gz"
cd ${utils_dir}
test_command "sudo tar -xvf ${utils_dir}/downloads/krbguess.tar.gz" "[+] KrbGuess installation complete" "[-] KrbGuess installation failed"

# Impacket
echo "[+] Installing Impacket"
# getting this URL is probably easier, but I didn't spend any time on it
latest_uri=$(curl -L -Ss https://github.com/SecureAuthCorp/impacket/releases/latest \
| grep "<a href=" \
| grep -E "impacket-.+\.tar\.gz" \
| awk '{$1=$1;print}' \
| cut -d "=" -f 2 \
| cut -d " " -f 1 \
| tr -d \")
curl_get "https://www.github.com"${latest_uri} ${utils_dir}"/downloads/impacket-latest.tar.gz"
sudo mkdir ${utils_dir}"/impacket"
cd ${utils_dir}"/downloads"
sudo tar -xvf impacket-latest.tar.gz --no-same-permissions
impacket_dir=$(ls -d */ | grep impacket)
sudo chown -R $current_user.$current_user ${impacket_dir}
cd ${utils_dir}"/downloads/"${impacket_dir}
sudo mv * ${utils_dir}"/impacket/"
cd ${utils_dir}"/impacket/"
test_command "sudo python3 setup.py install" "[+] Impacket installation complete" "[-] Impacket installation failed"

# kerbrute
# simple - just download the binary from latest releases
latest_uri=$(curl -L -Ss https://github.com/ropnop/kerbrute/releases/latest \
| grep "<a href=" \
| grep -E "kerbrute_linux_amd64" \
| awk '{$1=$1;print}' \
| cut -d "=" -f 2 \
| cut -d " " -f 1 \
| tr -d \")
curl_get "https://www.github.com"${latest_uri} ${utils_dir}"/downloads/kerbrute_linux_amd64"
sudo mkdir ${utils_dir}"/kerbrute"
sudo mv ${utils_dir}"/downloads/kerbrute_linux_amd64" ${utils_dir}"/kerbrute/kerbrute"
sudo chmod +x ${utils_dir}"/kerbrute/kerbrute"

# sipscan
echo "[+] Installing SIPPTS"
cd ${utils_dir}"/downloads"
git clone https://github.com/Pepelux/sippts.git
cpan -i IO:Socket:Timeout
cpan -i NetAddr:IP
cpan -i String:HexConvert
cpan -i Net:Pcap
cpan -i Net::Address::IP::Local
cpan -i DBD::SQLite
sudo ln -s ${utils_dir}"/downloads/sippts" ${utils_dir}"/sippts"

# Setup openvas
echo "[*] setting up OpenVAS"
sudo greenbone-nvt-sync &
sudo greenbone-scapdata-sync &
sudo greenbone-certdata-sync &
wait

# instructions
echo "FINAL INSTRUCTIONS:"
echo "1. Update tmux if open: tmux source ~/.tmux.conf"
echo "2. Install tmux plugins: <prefix> + I"