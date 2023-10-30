#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
    echo "###### This script must be run as root #######"
    exit 1
fi

# First configure the Linux host to meet the Splunk Enterprise system requirements
# https://docs.splunk.com/Documentation/Splunk/8.1.2/Installation/Systemrequirements#System_requirements_for_Linux

# Disable THP on boot
echo "############ Disabling THP on boot #############"
cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=splunk.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=basic.target
EOF

# Update Ulimits
echo "############ Updating Ulimits #############"
cat > /etc/security/limits.d/99-splunk.conf << 'EOF'
splunk_user soft nofile 64000
splunk_user hard nofile 64000
splunk_user soft nproc 20480
splunk_user hard nproc 20480
EOF

# Update Kernel Parameters
echo "############ Updating Kernel Parameters #############"
cat > /etc/sysctl.d/99-splunk.conf << 'EOF'
vm.max_map_count=262144
EOF

# Reload Systemd
echo "############## Reloading Systemd ###############"
systemctl daemon-reload

############################### Splunk Enterprise Installation ###############################
# 1. Create a splunk_user with sudo privileges and no password
echo "###### Creating splunk_user with sudo privileges and no password ########"
sudo useradd -m -s /bin/bash splunk_user
echo "splunk_user ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# 2. Install Splunk from the provided URL
wget -O /tmp/splunk.tgz https://download.splunk.com/products/splunk/releases/9.1.0.2/linux/splunk-9.1.0.2-b6436b649711-Linux-x86_64.tgz

# 3. Extract and install
tar -xzvf /tmp/splunk.tgz -C /opt/

# 4.0 Add Default Splunk Admin user and password
echo "###### Adding default Splunk Admin user and password ########"

cat > /opt/splunk/etc/system/local/user-seed.conf << 'EOF'
[user_info]
USERNAME = admin
PASSWORD = Pngoingin2@
EOF

# 4.1 Disable disk usage warning
cat > /opt/splunk/etc/system/local/server.conf << 'EOF'
[diskUsage]
minFreeSpace = 0
EOF

# 4.2 Change ownership
echo "############ Changing ownership of /opt/splunk to splunk_user #############"
sudo chown -R splunk_user:splunk_user /opt/splunk
# sleep 2s

# 5. Start Boot start
echo "############# Enabling Splunk to start at boot via Systemd ##############"
/opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk_user --accept-license --answer-yes --no-prompt

# sleep 2s
# 6. Change ownership
sudo chown -R splunk_user:splunk_user /opt/splunk

# 7. Reload Systemd
echo "############## Reloading Systemd ###############"
systemctl daemon-reload

echo "############## Enabling Splunkd ##############"
systemctl enable Splunkd

echo "############### Starting Splunkd ###############"
systemctl start Splunkd

# Check Splunkd status
sleep 5s
echo "############### Checking Splunkd status ################"
# systemctl status Splunkd
if sudo systemctl status Splunkd | grep -q "active (running)"; then
    echo "Splunkd is running"
else
    echo "Splunkd is not running"
    exit 1
fi
