#!/usr/bin/env bash
#
# Setup script for Kali pen testing image.
# Adds additional scripts, files, and binaries.

if [ "$#" -lt 1 ]; then
    echo "Usage: kali_setup.sh <local bin directory>"
    echo "Example: kali_setup.sh /home/user/bin"
    exit 1
fi

local_bin_dir=$1
utils_dir="/opt/utils/"

curl_get() {
    url=$1
    file=$2
    return_value=0  # assume success unless something happens

    result=$(curl -sS --connect-timeout 5 "$url" > $file)
    if [ $? -ne 0 ]; then
        echo "[-] Unable to retrieve $url"
        echo "[-] Curl error:"
        echo "$result"
        rm $file
        return_value=1
    fi

    return $return_value
}

# make the necessary directories
mkdir ${local_bin_dir}
mkdir -p ${utils_dir}"downloads"

# my scripts
echo "Installing my scripts"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/masscan.sh ${local_bin_dir}"/masscan.sh"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/nmap.sh ${local_bin_dir}"/nmap.sh"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/scan_host_list.py ${local_bin_dir}"/scan_host_list.py"
curl_get https://raw.githubusercontent.com/jordantrc/port_scanners/master/false_positive_test.sh ${local_bin_dir}"/false_positive_test.sh"
curl_get https://raw.githubusercontent.com/jordantrc/enumeration/master/http-security-check.sh ${local_bin_dir}"/http-security-check.sh"

# other people's work
echo "Installing RDPScan by Robert Graham"
zip_file_location=${utils_dir}"downloads/rdpscan.zip"
curl_get https://github.com/robertdavidgraham/rdpscan/archive/master.zip ${zip_file_location}
sudo apt install libssl-dev

