#!/bin/bash

# DevOpsFetch Installation Script

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or using sudo."
  # Rerun the script with sudo
  sudo -E "$0" "$@"
  exit 1
fi


# Install dependencies
echo "####################### Installing Dependencies... ####################################"
sudo apt-get update
sudo apt-get install -y docker.io nginx



# Copy the main script to /usr/local/bin
echo "########################## Copy the devopsfetch script to the bin directoty #######################"
sudo cp devopsfetch.sh /usr/local/bin/devopsfetch

# Make the script executable
echo "########################## Making the devopsfetch command line script executable #######################"
chmod +x /usr/local/bin/devopsfetch
chmod +x devopsfetch.sh



# Create the logfile
echo "####################### Creating log file...####################################"
create_log_directory() {
    local dir="/var/log"

    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist. Creating..."
        mkdir -p "$dir"
        echo "Directory $dir created."
    else
        echo "Directory $dir already exists."
    fi
}

touch /var/log/devopsfetch.log
chmod 666 /var/log/devopsfetch.log

echo "####################### Creating monitoring script...####################################"
cat << 'EOF' | sudo tee /usr/local/bin/devopsfetch_monitor.sh
#!/bin/bash

LOG_FILE="/var/log/devopsfetch.log"

while true; do
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "---" | sudo tee -a "${LOG_FILE}"
    echo "${timestamp}: Running DevOpsFetch" | sudo tee -a "${LOG_FILE}"
    echo "${timestamp}: Ports" | sudo tee -a "${LOG_FILE}"
    /usr/local/bin/devopsfetch -p | sudo tee -a "${LOG_FILE}"
    echo "${timestamp}: Docker" | sudo tee -a "${LOG_FILE}"
    /usr/local/bin/devopsfetch -d | sudo tee -a "${LOG_FILE}"
    echo "${timestamp}: Nginx" | sudo tee -a "${LOG_FILE}"
    /usr/local/bin/devopsfetch -n | sudo tee -a "${LOG_FILE}"
    echo "${timestamp}: Users" | sudo tee -a "${LOG_FILE}"
    /usr/local/bin/devopsfetch -u | sudo tee -a "${LOG_FILE}"
    sleep 120  # Run every 2 minutes
done
EOF

# Make the monitoring script executable
echo "######################### Making the monitoring for devopsfetch executable  ####################"
chmod +x /usr/local/bin/devopsfetch_monitor.sh


# Set up log rotation
echo "######################### Creating a log rotation file  ####################"
cat << EOF | sudo tee /etc/logrotate.d/devopsfetch
/var/log/devopsfetch.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create systemd service file
echo "######################### Creating a systemd service file  ####################"
cat << EOF | sudo tee /etc/systemd/system/devopsfetch.service
[Unit]
Description=DevOpsFetch Service
After=network.target
[Service]
ExecStart=/usr/local/bin/devopsfetch_monitor.sh
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl enable devopsfetch.service
sudo systemctl start devopsfetch.service
sudo systemctl daemon-reload
sudo systemctl enable devopsfetch.service
sudo systemctl start devopsfetch.service

echo "Installation complete. DevOpsFetch is now installed and the monitoring service is running."
echo "You can use 'devopsfetch' command to retrieve system information."
echo "Logs are being written to /var/log/devopsfetch.log"