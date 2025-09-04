#!/bin/bash
# Complete USB Printer Capture System Installation
# For Raspberry Pi Zero W with Raspberry Pi OS Lite
# Usage: sudo bash install.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Must run as root: sudo bash $0${NC}"
    exit 1
fi

# Get actual user and current directory
REAL_USER=${SUDO_USER:-$(logname)}
USER_HOME="/home/$REAL_USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo -e "${BLUE}"
echo "==========================================="
echo "      PRINTJACK SYSTEM INSTALLATION"
echo "==========================================="
echo -e "${NC}"
echo "Installing for user: $REAL_USER"
echo "User home: $USER_HOME"
echo "Project directory: $PROJECT_DIR ($(basename "$PROJECT_DIR"))"
echo ""

# 1. Update system
echo -e "${YELLOW}[1/10] Updating system packages...${NC}"
apt update
apt upgrade -y

# 2. Install required packages
echo -e "${YELLOW}[2/10] Installing required packages...${NC}"

PACKAGES=(
    "python3"
    "python3-pip"
    "sqlite3"
    "libgxps-utils"      # XPS to PDF conversion (xpstopdf)
    "ghostscript"        # PostScript/PCL conversion (ps2pdf, gs)
    "poppler-utils"      # PDF utilities (pdftoppm, pdfinfo)
    "netpbm"            # Image conversion utilities
    "psmisc"            # fuser command
    "lsof"              # lsof command for debugging
    "hostapd"           # WiFi hotspot capability (optional)
    "dnsmasq"           # DHCP server for hotspot (optional)
)

for package in "${PACKAGES[@]}"; do
    echo "  Installing $package..."
    if apt install -y "$package"; then
        echo -e "    ${GREEN}✓${NC} $package installed"
    else
        echo -e "    ${RED}✗${NC} Failed to install $package"
    fi
done

# 3. Configure USB OTG in boot files
echo -e "${YELLOW}[3/10] Configuring USB OTG...${NC}"

# Simple boot file detection
if [ -f "/boot/firmware/config.txt" ]; then
    BOOT_DIR="/boot/firmware"
elif [ -f "/boot/config.txt" ]; then
    BOOT_DIR="/boot"
else
    echo -e "${RED}✗${NC} Boot files not found in /boot/firmware/ or /boot/"
    echo "  Please check if you're running this on the Pi directly"
    echo "  or if the boot partition is properly mounted"
    exit 1
fi

BOOT_CONFIG="$BOOT_DIR/config.txt"
BOOT_CMDLINE="$BOOT_DIR/cmdline.txt"

echo "  Using boot directory: $BOOT_DIR/"

# Backup boot files
echo "  Creating backups..."
cp "$BOOT_CONFIG" "${BOOT_CONFIG}.backup.$(date +%Y%m%d)"
cp "$BOOT_CMDLINE" "${BOOT_CMDLINE}.backup.$(date +%Y%m%d)"
cp /etc/modules /etc/modules.backup.$(date +%Y%m%d)
echo -e "    ${GREEN}✓${NC} Boot file backups created"

# Configure config.txt
echo "  Configuring $BOOT_CONFIG..."

# Remove any conflicting dwc2 overlays
sed -i '/dtoverlay=dwc2/d' "$BOOT_CONFIG"

# Add USB OTG configuration
if ! grep -q "dtoverlay=dwc2" "$BOOT_CONFIG"; then
    cat >> "$BOOT_CONFIG" << 'EOF'

# USB OTG for Pi Zero W - USB Printer Capture System
dtoverlay=dwc2,dr_mode=peripheral
EOF
    echo -e "    ${GREEN}✓${NC} USB OTG configuration added to config.txt"
else
    echo -e "    ${GREEN}✓${NC} USB OTG already configured"
fi

# Configure cmdline.txt
echo "  Configuring $BOOT_CMDLINE..."

CMDLINE_CONTENT=$(cat "$BOOT_CMDLINE")

if [[ ! "$CMDLINE_CONTENT" == *"modules-load=dwc2"* ]]; then
    sed -i 's/rootwait/rootwait modules-load=dwc2/g' "$BOOT_CMDLINE"
    echo -e "    ${GREEN}✓${NC} Added modules-load=dwc2 to cmdline.txt"
else
    echo -e "    ${GREEN}✓${NC} modules-load=dwc2 already configured"
fi

# Configure modules
echo "  Configuring /etc/modules..."

if ! grep -q "^libcomposite$" /etc/modules; then
    echo "libcomposite" >> /etc/modules
    echo -e "    ${GREEN}✓${NC} Added libcomposite to /etc/modules"
else
    echo -e "    ${GREEN}✓${NC} libcomposite already in /etc/modules"
fi

# 4. Create project directory structure
echo -e "${YELLOW}[4/10] Creating project structure...${NC}"

mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/captured_print_jobs"
mkdir -p "$PROJECT_DIR/captured_print_jobs/converted"
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/bin"

chown -R "$REAL_USER:$REAL_USER" "$PROJECT_DIR"
echo -e "  ${GREEN}✓${NC} Project directories created"

# 5. Test USB gadget module loading
echo -e "${YELLOW}[5/10] Testing USB gadget modules...${NC}"

echo "  Loading libcomposite..."
if modprobe libcomposite; then
    echo -e "    ${GREEN}✓${NC} libcomposite loaded"
else
    echo -e "    ${RED}✗${NC} Failed to load libcomposite"
fi

echo "  Loading usb_f_printer..."
if modprobe usb_f_printer; then
    echo -e "    ${GREEN}✓${NC} usb_f_printer loaded" 
else
    echo -e "    ${RED}✗${NC} Failed to load usb_f_printer"
fi

# 6. Check USB Device Controller
echo -e "${YELLOW}[6/10] Checking USB Device Controller...${NC}"

if ls /sys/class/udc/ >/dev/null 2>&1 && [ "$(ls /sys/class/udc/ | wc -l)" -gt 0 ]; then
    UDC_NAME=$(ls /sys/class/udc/ | head -n1)
    echo -e "  ${GREEN}✓${NC} USB Device Controller found: $UDC_NAME"
else
    echo -e "  ${YELLOW}!${NC} USB Device Controller not available (requires reboot)"
fi

# 7. Set up convenience commands (cleaner approach)
echo -e "${YELLOW}[7/10] Setting up PrintJack commands...${NC}"

# Option 1: Create a bin directory inside PrintJack
mkdir -p "$PROJECT_DIR/bin"

# Create convenience scripts inside PrintJack/bin/
cat > "$PROJECT_DIR/bin/start-printjack" << EOF
#!/bin/bash
cd $PROJECT_DIR
sudo bash start-printjack-gadget.sh
EOF

cat > "$PROJECT_DIR/bin/capture-printjack" << EOF
#!/bin/bash
cd $PROJECT_DIR
sudo python3 printjack_capture.py
EOF

cat > "$PROJECT_DIR/bin/convert-printjack" << EOF
#!/bin/bash
cd $PROJECT_DIR
python3 convert_captures.py captured_print_jobs/
EOF

cat > "$PROJECT_DIR/bin/printjack" << EOF
#!/bin/bash
cd $PROJECT_DIR
sudo bash printjack.sh
EOF

# Make them executable
chmod +x "$PROJECT_DIR/bin/"*
chown -R "$REAL_USER:$REAL_USER" "$PROJECT_DIR/bin/"

# Option 2: Add aliases to .bashrc instead of creating files in home
if ! grep -q "PrintJack aliases" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << EOF

# PrintJack aliases (auto-generated - location: $PROJECT_DIR)
alias printjack='cd "$PROJECT_DIR" && sudo bash printjack.sh'
alias start-printjack='cd "$PROJECT_DIR" && sudo bash start-printjack-gadget.sh'
alias capture-printjack='cd "$PROJECT_DIR" && sudo python3 printjack_capture.py'
alias convert-printjack='cd "$PROJECT_DIR" && python3 convert_captures.py captured_print_jobs/'
alias printjack-help='cd "$PROJECT_DIR" && bash help.sh'
alias printjack-server='cd "$PROJECT_DIR" && sudo python3 printjack_exfil.py'
alias printjack-ducky='cd "$PROJECT_DIR" && python3 printjack_ducky.py'
alias printjack-fuzz='cd "$PROJECT_DIR" && python3 printjack_ducky_fuzz.py'
EOF
    echo -e "  ${GREEN}✓${NC} PrintJack aliases added to .bashrc"
else
    echo -e "  ${GREEN}✓${NC} PrintJack aliases already in .bashrc"
fi

echo -e "  ${GREEN}✓${NC} Convenience commands created in $PROJECT_DIR/bin/"

# 8. Set up exfiltration and ducky scripts
echo -e "${YELLOW}[8/10] Setting up exfiltration and ducky scripts...${NC}"

# Make file server scripts executable
if [ -f "$PROJECT_DIR/printjack_exfil.py" ]; then
    chmod +x "$PROJECT_DIR/printjack_exfil.py"
    chown "$REAL_USER:$REAL_USER" "$PROJECT_DIR/printjack_exfil.py"
    echo -e "  ${GREEN}✓${NC} printjack_exfil.py ready"
else
    echo -e "  ${YELLOW}!${NC} printjack_exfil.py not found - copy manually"
fi

if [ -f "$PROJECT_DIR/printjack_ducky.py" ]; then
    chmod +x "$PROJECT_DIR/printjack_ducky.py"
    chown "$REAL_USER:$REAL_USER" "$PROJECT_DIR/printjack_ducky.py" 
    echo -e "  ${GREEN}✓${NC} printjack_ducky.py ready"
else
    echo -e "  ${YELLOW}!${NC} printjack_ducky.py not found - copy manually"
fi

# Add file server convenience scripts
cat > "$PROJECT_DIR/bin/printjack-server" << EOF
#!/bin/bash
cd $PROJECT_DIR
sudo python3 printjack_exfil.py
EOF


cat > "$PROJECT_DIR/bin/printjack-ducky" << EOF
#!/bin/bash
cd $PROJECT_DIR
python3 printjack_ducky.py
EOF

cat > "$PROJECT_DIR/bin/printjack-fuzz" << EOF
#!/bin/bash
cd $PROJECT_DIR
python3 printjack_ducky_fuzz.py
EOF

chmod +x "$PROJECT_DIR/bin/printjack-server"
chmod +x "$PROJECT_DIR/bin/printjack-ducky"
chmod +x "$PROJECT_DIR/bin/printjack-fuzz"
chown -R "$REAL_USER:$REAL_USER" "$PROJECT_DIR/bin/"

echo -e "  ${GREEN}✓${NC} File server commands created"

# 9. Install systemd services
echo -e "${YELLOW}[9/10] Setting up systemd services...${NC}"

# PrintJack capture service
cat > /etc/systemd/system/printjack-capture.service << EOF
[Unit]
Description=PrintJack Capture Service
After=multi-user.target
Wants=multi-user.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStartPre=$PROJECT_DIR/start-printjack-gadget.sh
ExecStart=/usr/bin/python3 $PROJECT_DIR/printjack_capture.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# PrintJack file server service
cat > /etc/systemd/system/printjack-server.service << EOF
[Unit]
Description=PrintJack File Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 $PROJECT_DIR/printjack_exfil.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "  ${GREEN}✓${NC} Systemd services installed"

# 10. Final verification
echo -e "${YELLOW}[10/10] Final verification...${NC}"

echo "  Checking script files..."
REQUIRED_FILES=(
    "$PROJECT_DIR/start-printjack-gadget.sh"
    "$PROJECT_DIR/printjack_capture.py"
    "$PROJECT_DIR/convert_captures.py"
    "$PROJECT_DIR/printjack.sh"
    "$PROJECT_DIR/help.sh"
    "$PROJECT_DIR/printjack_exfil.py"
    "$PROJECT_DIR/printjack_ducky.py"
    "$PROJECT_DIR/printjack_ducky_fuzz.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod +x "$file"
        chown "$REAL_USER:$REAL_USER" "$file"
        echo -e "    ${GREEN}✓${NC} $(basename "$file") ready"
    else
        echo -e "    ${RED}✗${NC} $(basename "$file") missing - copy script manually"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  PRINTJACK INSTALLATION SUCCESSFUL${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Reboot the system (required for USB OTG)"
echo "2. Connect USB cable to target computer"
echo "3. Source your bashrc: source ~/.bashrc"
echo "4. EASY WAY: Run 'printjack' (does everything automatically)"
echo "   OR MANUAL WAY:"
echo "   a. Run: start-printjack (starts USB gadget)"
echo "   b. Run: capture-printjack (starts capture daemon)"
echo "5. Add printer in Windows (use Microsoft XPS driver)"
echo "6. Print documents to capture them"
echo "7. Files are auto-converted, or run: convert-printjack"
echo ""
echo -e "${BLUE}Quick Reference:${NC}"
echo "  printjack             # ALL-IN-ONE: Start everything automatically"
echo "  start-printjack       # Start PrintJack gadget only"
echo "  capture-printjack     # Start capturing print jobs"  
echo "  convert-printjack     # Convert captured files manually"
echo "  printjack-server      # Start file sharing server"
echo "  printjack-ducky       # Run USB rubber ducky"
echo "  printjack-fuzz        # Run USB port fuzzing for auto-printer setup"
echo "  printjack-help        # Show Help menu"
echo ""
echo -e "${BLUE}File Server Usage:${NC}"
echo "  printjack-server                      # Start file server"
echo "  sudo systemctl enable printjack-server    # Auto-start server"
echo "  Visit http://[pi-ip] in browser       # Access shared files"
echo "  Default folder: captured_print_jobs/converted/"
echo ""
echo -e "${BLUE}Alternative (if aliases don't work):${NC}"
echo "  cd ~/PrintJack && ./bin/printjack"
echo "  cd ~/PrintJack && ./bin/start-printjack"
echo "  cd ~/PrintJack && ./bin/printjack-server"
echo "  cd ~/PrintJack && ./bin/printjack-fuzz"
echo ""
echo -e "${BLUE}File Locations:${NC}"
echo "  Scripts: $PROJECT_DIR/"
echo "  Commands: $PROJECT_DIR/bin/"
echo "  Captured: $PROJECT_DIR/captured_print_jobs/"
echo "  Converted: $PROJECT_DIR/captured_print_jobs/converted/"
echo "  Logs: $PROJECT_DIR/logs/"
echo ""

# Offer to reboot
echo -e "${YELLOW}Reboot now to enable USB OTG? (y/n):${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    reboot
else
    echo -e "${YELLOW}Remember to reboot before using the system!${NC}"
fi