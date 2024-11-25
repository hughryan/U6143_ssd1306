# Check if the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Enable I2C Interface in /boot/config.txt
if grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
    echo "I2C is already enabled in /boot/config.txt."
elif grep -q "^#dtparam=i2c_arm=off" /boot/config.txt; then
    echo "Enabling I2C and replacing the existing line in /boot/config.txt."
    sudo sed -i 's/^#dtparam=i2c_arm=off/dtparam=i2c_arm=on/' /boot/config.txt
else
    echo "I2C line not found. Adding I2C enable line to /boot/config.txt."
    echo "dtparam=i2c_arm=on" | sudo tee -a /boot/config.txt
fi

# Load I2C Kernel Modules
if grep -q "i2c-dev" /etc/modules; then
    echo "i2c-dev module already exists in /etc/modules."
else
    echo "Adding i2c-dev module to /etc/modules."
    echo "i2c-dev" >> /etc/modules
fi

# Install necessary packages for building RPi.GPIO
apt-get update &&  apt-get install -y --no-install-recommends \
python3 \
build-essential \
python3-pip \
python3-pil \
i2c-tools \
fontconfig

# Get the current Python3 version
PYTHON_VERSION=$(python3 -V | cut -d " " -f 2 | cut -d "." -f 1,2)

# Install Python development package for the current Python version
sudo apt-get update
sudo apt-get install -y --no-install-recommends "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv"

# Create a Python virtual environment
VENV_PATH="/usr/local/share/ssd1306_venv"
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

# Install necessary Python packages
pip install -r "$REPO_DIR/requirements.txt"

# Deactivate the virtual environment
deactivate

# Copy the font file to the system's fonts directory
mkdir -p /usr/local/share/fonts/
cp "$REPO_DIR/fonts/"* /usr/local/share/fonts/
fc-cache -fv

# Copy the Python scripts to /usr/local/bin
cp "$REPO_DIR/src/ssd1306_display.py" /usr/local/bin/ssd1306_display
cp "$REPO_DIR/src/ssd1306_shutdown.py" /usr/local/bin/ssd1306_shutdown

# Make the scripts executable
chmod +x /usr/local/bin/ssd1306_display
chmod +x /usr/local/bin/ssd1306_shutdown

# Create systemd service file
cat <<EOF > /etc/systemd/system/ssd1306_display.service
[Unit]
Description=Chart Performance Display Service
After=network.target

[Service]
Type=simple
ExecStart=$VENV_PATH/bin/python /usr/local/bin/ssd1306_display
ExecStopPost=$VENV_PATH/bin/python /usr/local/bin/ssd1306_shutdown

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
systemctl daemon-reload

# Enable the service to start on boot
systemctl enable ssd1306_display.service

# Start the service
systemctl restart ssd1306_display.service

echo "The SSD1306 display service has been configured and started."
