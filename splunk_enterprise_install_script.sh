#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# 1. Create a splunk_user with sudo privileges and no password
echo "Creating splunk_user with sudo privileges and no password"
sudo useradd -m -s /bin/bash splunk_user
echo "splunk_user ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# 2. Install Splunk from the provided URL
wget -O /tmp/splunk.tgz https://download.splunk.com/products/splunk/releases/9.1.0.2/linux/splunk-9.1.0.2-b6436b649711-Linux-x86_64.tgz

# 3. Extract and install
tar -xzvf /tmp/splunk.tgz -C /opt/

# 4. Add Default Splunk Admin user and password
echo "Adding default Splunk Admin user and password"

cat > /opt/splunk/etc/system/local/user-seed.conf << 'EOF'
[user_info]
USERNAME = admin
PASSWORD = 12345
EOF

cat > /opt/splunk/etc/system/local/server.conf << 'EOF'
[diskUsage]

minFreeSpace = 0
EOF

# 4.1 Change ownership
echo "Changing ownership of /opt/splunk to splunk_user"
sudo chown -R splunk_user:splunk_user /opt/splunk
# sleep 2s

# 5. Start Boot start
echo "Enabling Splunk to start at boot via Systemd"
/opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk_user --accept-license --answer-yes --no-prompt

# sleep 2s
# 6. Change ownership
sudo chown -R splunk_user:splunk_user /opt/splunk

# 7. Reload Systemd
echo "Reloading Systemd"
systemctl daemon-reload

echo "Enabling Splunkd"
systemctl enable Splunkd

echo "Starting Splunkd"
systemctl start Splunkd

# Check Splunkd status
sleep 5s
echo "Checking Splunkd status"
systemctl status Splunkd
if [ $? -eq 0 ]; then
    echo "Splunkd is running"
else
    echo "Splunkd is not running"
fi
