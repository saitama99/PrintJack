#!/usr/bin/env python3
"""
Bidirectional USB Printer - Responds to Windows printer queries
Usage: sudo python3 bidirectional_printer.py
"""

import os
import sys
import time
import signal
from datetime import datetime
from pathlib import Path

class BidirectionalPrinter:
    def __init__(self, device='/dev/g_printer0', capture_dir='captured_print_jobs'):
        self.device = device
        self.capture_dir = Path(capture_dir).expanduser()
        self.capture_dir.mkdir(exist_ok=True)
        self.job_counter = 1
        self.running = True
        self.current_job_data = b''
        
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
        
    def signal_handler(self, signum, frame):
        print(f"\nShutting down...")
        self.running = False
        
    def is_printer_command(self, data):
        """Detect if data contains printer control commands"""
        if not data or len(data) > 100:
            return False
            
        # Form feeds and control characters
        if data in [b'\x0c', b'\x0c\x0c', b'\x05', b'\x04']:
            return True
            
        # Short data with mostly control characters
        if len(data) <= 10 and all(b <= 32 or b >= 127 for b in data):
            return True
            
        return False
        
    def generate_response(self, command_data):
        """Generate printer response"""
        if command_data == b'\x05':  # ENQ (enquiry)
            return b'\x06'  # ACK (acknowledge)
        elif b'\x0c' in command_data:  # Form feed
            return b'\x06'  # ACK - tell Windows we processed it
        elif command_data == b'\x04':  # EOT (end of transmission)
            return b'\x06'  # ACK
        else:
            return b'\x06'  # Generic ACK for any other command
            
    def detect_file_type(self, data):
        """Detect file type"""
        if not data:
            return '.txt', 'Empty'
            
        if data.startswith(b'PK'):
            # Check if it's XPS (ZIP archive with XPS content)
            if b'[Content_Types].xml' in data[:1000] or b'_rels/.rels' in data[:1000]:
                return '.xps', 'XPS'
            else:
                return '.zip', 'ZIP'
        elif data.startswith(b'%PDF'):
            return '.pdf', 'PDF'
        elif data.startswith(b'%!PS'):
            return '.ps', 'PostScript'
        elif data.startswith(b'\x1b') and len(data) > 100:
            return '.pcl', 'PCL'
        elif all(b < 128 for b in data[:50] if b != 0):
            return '.txt', 'Text'
        else:
            return '.bin', 'Binary'
            
    def save_job(self, data):
        """Save captured job"""
        if len(data) < 10:
            return
            
        extension, file_type = self.detect_file_type(data)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"job_{self.job_counter}_{timestamp}{extension}"
        filepath = self.capture_dir / filename
        
        with open(filepath, 'wb') as f:
            f.write(data)
            
        print(f"\nâœ“ CAPTURED JOB #{self.job_counter}")
        print(f"  File: {filename}")
        print(f"  Type: {file_type}")
        print(f"  Size: {len(data)} bytes")
        print(f"  Path: {filepath}")
        
        if file_type == 'Text':
            try:
                preview = data[:200].decode('utf-8', errors='ignore').strip()
                if preview:
                    print(f"  Preview: {preview[:60]}...")
            except:
                pass
                
        print("=" * 50)
        self.job_counter += 1
        
    def run(self):
        """Main loop"""
        if os.geteuid() != 0:
            print("Error: Must run as root")
            return 1
            
        if not os.path.exists(self.device):
            print(f"Error: {self.device} not found")
            print("Start USB printer first: sudo bash start-usb-printer.sh")
            return 1
            
        print(f"Bidirectional USB Printer Started")
        print(f"Device: {self.device}")
        print(f"Saving to: {self.capture_dir}")
        print(f"Press Ctrl+C to stop\n")
        
        last_data_time = time.time()
        
        try:
            device_fd = os.open(self.device, os.O_RDWR | os.O_NONBLOCK)
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Device opened in bidirectional mode...")
            
            try:
                while self.running:
                    try:
                        data = os.read(device_fd, 4096)
                        if data:
                            last_data_time = time.time()
                            
                            if self.is_printer_command(data):
                                print(f"[{datetime.now().strftime('%H:%M:%S')}] Printer command: {data} ({len(data)} bytes)")
                                
                                response = self.generate_response(data)
                                if response:
                                    os.write(device_fd, response)
                                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent response: {response}")
                                
                                # Save any accumulated data first
                                if len(self.current_job_data) > 50:
                                    self.save_job(self.current_job_data)
                                    self.current_job_data = b''
                            else:
                                # Document data
                                if not self.current_job_data:
                                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Document transfer starting...")
                                
                                self.current_job_data += data
                                print(f"[{datetime.now().strftime('%H:%M:%S')}] +{len(data)} bytes, total: {len(self.current_job_data)}")
                                
                    except BlockingIOError:
                        # No data available
                        time.sleep(0.1)
                        
                        # Check for timeout
                        if (self.current_job_data and 
                            len(self.current_job_data) > 50 and 
                            time.time() - last_data_time > 3):
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] Transfer complete (timeout)")
                            self.save_job(self.current_job_data)
                            self.current_job_data = b''
                            
            finally:
                os.close(device_fd)
                
        except KeyboardInterrupt:
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Interrupted by user")
        except Exception as e:
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Error: {e}")
            return 1
            
        # Save any remaining data
        if len(self.current_job_data) > 10:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Saving final data")
            self.save_job(self.current_job_data)
            
        print("Bidirectional printer stopped")
        return 0

def main():
    printer = BidirectionalPrinter()
    return printer.run()

if __name__ == '__main__':
    sys.exit(main())