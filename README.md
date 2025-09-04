# PrintJack - USB Printer Capture & Intercept System

## Overview

PrintJack is a comprehensive USB printer emulation and data capture framework designed for penetration testing and red team operations. Built on Raspberry Pi Zero W hardware, it presents itself as a legitimate USB printer to target systems while capturing, converting, and exfiltrating print jobs.

## Key Features

### Core Functionality
- **USB Printer Gadget Emulation** - Appears as legitimate USB printer to target systems
- **Print Job Interception** - Captures XPS, PDF, PostScript, and plain text documents
- **Automatic File Conversion** - Background conversion of captured files to PDF format
- **Multi-format Support** - Handles various print job formats transparently

### Advanced Capabilities
- **File Exfiltration Server** - Web-based file access for remote document retrieval
- **USB Rubber Ducky Integration** - HID keyboard attack capabilities (used for autoinstallation on USB001 for Windows)
- **USB Port Fuzzing** - Automated printer installation across multiple USB ports (if unsure what port the device is connected to)
- **Stealth Operation** - Minimal system footprint and automated background processing

### Operational Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Capture Only** | Basic print job interception | Document collection |
| **Exfiltration** | Capture + web server | Remote file access |
| **Ducky** | Capture + HID attacks (for USB001 auto instalaltion) | Combined data/payload delivery |
| **Fuzzing** | Capture + auto-installation | Automated printer setup |

## Technical Specifications

### Hardware Requirements
- **Primary**: Raspberry Pi Zero W (recommended)
- **Alternative**: Raspberry Pi 4 with USB OTG capability
- **Storage**: Minimum 8GB microSD card
- **Connectivity**: USB data cable (not power-only)

### Software Dependencies
- Raspberry Pi OS Lite (Bullseye or Bookworm)
- Python 3.x with standard libraries
- USB Gadget kernel modules (`libcomposite`, `usb_f_printer`, `usb_f_hid`)
- Document conversion utilities (`ghostscript`, `poppler-utils`, `libgxps-utils`)

### Network Requirements
- WiFi connectivity for exfiltration mode
- Target and PrintJack on same network segment for web access

## Installation

### Automated Installation
```bash
git clone https://github.com/your-org/printjack.git
cd printjack
sudo bash install.sh
sudo reboot
```

### Manual Installation
See `install.sh` for detailed step-by-step installation procedures.

## Usage

### Quick Start
```bash
# Basic print capture
sudo printjack

# Print capture with file exfiltration
sudo printjack --exfil

# Print capture with USB rubber ducky
sudo printjack --ducky

# Print capture with automated printer setup
sudo printjack --fuzz

# Combined operations
sudo printjack --exfil --ducky
```

### Command Reference
```bash
printjack [OPTIONS]

Options:
  -e, --exfil    Enable file exfiltration server (port 80)
  -d, --ducky    Enable USB rubber ducky functionality
  -f, --fuzz     Enable USB port fuzzing for auto-installation
  -h, --help     Display usage information

Note: --ducky and --fuzz are mutually exclusive
```

### Individual Service Control
```bash
start-printjack      # Initialize USB gadget only
capture-printjack    # Start print job capture
convert-printjack    # Manual file conversion
printjack-server     # File exfiltration server only
printjack-ducky      # USB rubber ducky only
printjack-fuzz       # USB port fuzzing only
```

## Target System Configuration

### Windows Printer Setup

If automated installation fails or is not desired, users can manually configure PrintJack as a printer:

0. Connect PrintJack via USB to target system
1. **Open Devices and Printers** - Access via Control Panel or Settings
2. **Add Printer** - Click "Add a printer" button
3. **Add Local Printer** - Select "Add a local printer"
4. **Select Port** - Under "Use an existing port", choose **USB00* (Generic Corp USB Printer)**
5. **Choose Manufacturer** - Select **Microsoft** from the manufacturer list
6. **Select Driver** - Choose **Microsoft XPS Class Driver**
7. **Use Current Driver** - Click "Use the driver that is currently installed"
8. **Complete Setup** - Finish installation with default settings

### Social Engineering Considerations

**Note**: In authorized penetration testing scenarios, social engineering techniques may be required to guide target users through manual installation steps. This could involve presenting as IT support or providing troubleshooting instructions that encourage the user to complete the printer setup process.

### Post-Installation Verification
```bash
# Verify PrintJack is receiving data
sudo bash printjack.sh

# Check if device appears correctly
ls -la /dev/g_printer*

# Monitor captured files
ls ~/PrintJack/captured_print_jobs/
```

### Supported Applications
- **Full Compatibility**: Microsoft Office Suite, Notepad, Windows built-in applications
- **Limited Compatibility**: Chrome, Adobe Acrobat (control commands only)
- **Recommended Driver**: Microsoft XPS Document Writer for maximum compatibility

## Operational Considerations

### Stealth and OPSEC
- Appears as legitimate "Microsoft XPS Document Writer" in system logs
- USB VID/PID mimics standard printer hardware
- Web server uses standard HTTP port (80) for exfiltration
- Background processes run with minimal system resource usage

### File Handling
- **Capture Location**: `~/PrintJack/captured_print_jobs/`
- **Converted Files**: `~/PrintJack/captured_print_jobs/converted/`
- **Supported Formats**: XPS → PDF, PS → PDF, direct PDF, plain text
- **Automatic Conversion**: 20-second interval background processing

### Manual File Conversion
```bash
# Convert XPS files to PDF
xpstopdf captured_print_jobs/job_1_20250827_153627.xps job_1.pdf

# Convert PostScript to PDF
ps2pdf captured_print_jobs/document.ps converted_document.pdf

# Batch conversion using PrintJack converter
python3 convert_captures.py captured_print_jobs/
```

### Network Exfiltration
- **Access URL**: `http://[pi-ip-address]/`
- **File Browser**: Web-based interface for document download
- **Remote Access**: Accessible from any device on same network
- **Security**: No authentication required (by design for testing scenarios)

## Advanced Features

### USB Rubber Ducky Integration
- HID keyboard emulation capabilities
- Custom payload execution on target systems
- Runs parallel to print capture operations
- Configurable via `printjack_ducky.py`

### USB Port Fuzzing
- Automated printer installation across USB ports 1-10
- Eliminates manual printer configuration requirement
- Uses Windows printer installation APIs
- Success rate depends on target system permissions and UAC settings

### Systemd Integration
```bash
# Enable auto-start services
sudo systemctl enable printjack-capture
sudo systemctl enable printjack-server

# Manual service control
sudo systemctl start printjack-capture
sudo systemctl status printjack-server
```

## Red Team Applications

### Document Intelligence Gathering
- Corporate document collection during physical access
- Print job analysis for sensitive information discovery
- Baseline establishment for document classification systems

### Network Reconnaissance
- Document metadata analysis for network topology insights
- User behavior pattern identification through print habits
- Application inventory via document format analysis

### Social Engineering Support
- Document template harvesting for spear-phishing campaigns
- Corporate communication style analysis
- Organizational structure mapping through document distribution

### Persistence and Lateral Movement
- USB-based initial access vector
- Document-based credential harvesting
- Print server infrastructure reconnaissance

## Security Considerations

### Defensive Countermeasures
- **USB Port Controls**: Group Policy restrictions on USB device installation
- **Print Auditing**: Windows print job logging and monitoring
- **Driver Restrictions**: Limitation of approved printer drivers

### Detection Vectors
- Unusual USB device enumeration patterns
- Unexpected printer installations in system logs
- Document conversion process signatures

## Troubleshooting

### Common Issues
```bash
# USB gadget initialization failures
sudo modprobe libcomposite
sudo modprobe usb_f_printer
ls /sys/class/udc/

# Boot configuration verification
grep "dtoverlay=dwc2" /boot/config.txt /boot/firmware/config.txt
grep "modules-load=dwc2" /boot/cmdline.txt /boot/firmware/cmdline.txt

# Service status checking
ps aux | grep printjack
sudo lsof -i :80

# System diagnostics
dmesg | tail -20
journalctl -u printjack-capture
```

### Log Locations
- **Converter Logs**: `~/PrintJack/logs/converter.log`
- **System Logs**: `journalctl -u printjack-capture`
- **Web Server Logs**: `journalctl -u printjack-server`

## Legal and Ethical Considerations

### Authorized Use Only
This tool is designed exclusively for authorized penetration testing, red team exercises, and security research activities. Users must ensure:

- **Written Authorization**: Documented permission for target system testing
- **Scope Compliance**: Activities remain within defined testing boundaries
- **Data Handling**: Secure handling and disposal of captured documents
- **Legal Compliance**: Adherence to applicable local, state, and federal laws

### Testing Requirements
- Test across multiple Raspberry Pi models
- Validate compatibility with various Windows versions
- Verify USB gadget functionality across different hardware configurations

## Disclaimer

The authors and contributors of PrintJack assume no responsibility for misuse of this software. This tool is provided "as is" without warranty of any kind. Users are solely responsible for ensuring their activities comply with applicable laws and organizational policies.

## Credits & Open-Source Acknowledgment

This project utilizes various open-source libraries developed by the community. The author of PrintJack does not claim ownership of these libraries and expresses gratitude to the open-source developers whose work made this tool possible.

---

**Version**: 1.0  
**Last Updated**: 2025  
**Compatibility**: Raspberry Pi OS Bullseye/Bookworm, Python 3.7+
