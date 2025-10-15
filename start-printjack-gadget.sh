#!/bin/bash
# USB Printer Gadget + HID Keyboard - Start Script
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash $0"
    exit 1
fi

echo "Starting USB printer + HID keyboard gadget..."

# Auto-detect USB Device Controller
UDC=$(ls /sys/class/udc/ 2>/dev/null | head -n 1)
if [ -z "$UDC" ]; then
    echo "ERROR: No USB Device Controller found!"
    echo "Make sure dwc2 is loaded and you rebooted after install"
    exit 1
fi
echo "Detected UDC: $UDC"

# Load modules
modprobe libcomposite
modprobe usb_f_printer
modprobe usb_f_hid

# Check if gadget already exists - if so, just restart it
if [ -d "/sys/kernel/config/usb_gadget/printer" ]; then
    echo "Existing gadget found - attempting to restart..."
    cd /sys/kernel/config/usb_gadget/printer
    
    # Try to enable the existing gadget
    echo "$UDC" > UDC 2>/dev/null || {
        echo "Failed to restart existing gadget"
        exit 1
    }
    
    # Check if device files were created
    if [ -e /dev/g_printer0 ] && [ -e /dev/hidg0 ]; then
        echo "Restarted existing USB composite gadget"
        echo "Printer: /dev/g_printer0"
        echo "Keyboard: /dev/hidg0"
        exit 0
    else
        echo "Failed to create device files"
        exit 1
    fi
fi

# Create gadget
mkdir -p /sys/kernel/config/usb_gadget/printer
cd /sys/kernel/config/usb_gadget/printer

# USB descriptors (composite device)
echo 0x04b8 > idVendor        # Epson vendor ID
echo 0x0005 > idProduct       # Generic printer product ID  
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB
echo 0x00 > bDeviceClass      # Composite device
echo 0x00 > bDeviceSubClass   # Composite device
echo 0x00 > bDeviceProtocol   # Composite device

# Strings
mkdir -p strings/0x409
echo "Generic Corp" > strings/0x409/manufacturer
echo "USB Printer + Keyboard" > strings/0x409/product
echo "123456789" > strings/0x409/serialnumber

# Configuration
mkdir -p configs/c.1/strings/0x409
echo "Config 1" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

# Printer Function
mkdir -p functions/printer.0
echo "MFG:Generic Corp;MDL:USB Printer;CLS:PRINTER;" > functions/printer.0/pnp_string
echo 1 > functions/printer.0/q_len

# HID Keyboard Function
mkdir -p functions/hid.0
echo 1 > functions/hid.0/protocol      # Keyboard
echo 1 > functions/hid.0/subclass     # Boot interface
echo 8 > functions/hid.0/report_length

# Standard USB keyboard descriptor
echo -ne \\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0 > functions/hid.0/report_desc

# Link both functions to config
ln -sf /sys/kernel/config/usb_gadget/printer/functions/printer.0 configs/c.1/printer.0
ln -sf /sys/kernel/config/usb_gadget/printer/functions/hid.0 configs/c.1/hid.0

# Enable gadget
echo "$UDC" > UDC

# Check result
if [ -e /dev/g_printer0 ] && [ -e /dev/hidg0 ]; then
    echo "USB composite gadget started"
    echo "Printer: /dev/g_printer0"
    echo "Keyboard: /dev/hidg0"
    echo "Connect USB cable to target computer"
else
    echo "Failed to create device files"
    echo "Printer: $([ -e /dev/g_printer0 ] && echo "OK" || echo "FAIL")"
    echo "Keyboard: $([ -e /dev/hidg0 ] && echo "OK" || echo "FAIL")"
    exit 1
fi
