#!/usr/bin/env python3
"""
Convert captured print jobs to readable formats
Usage: python3 convert-captures.py [file_or_directory]
"""

import os
import sys
import subprocess
from pathlib import Path
import argparse

class PrintJobConverter:
    def __init__(self):
        self.supported_conversions = {
            '.xps': ['pdf', 'png'],
            '.ps': ['pdf', 'png', 'txt'],
            '.pcl': ['pdf', 'txt'],
        }
        
    def check_dependencies(self):
        """Check if required conversion tools are installed"""
        tools = {
            'xpstopdf': 'libgxps-utils',
            'ps2pdf': 'ghostscript',
            'pstopnm': 'netpbm',
            'pcl6': 'ghostscript'
        }
        
        missing = []
        for tool, package in tools.items():
            if not self.command_exists(tool):
                missing.append(f"{tool} (install with: sudo apt install {package})")
                
        if missing:
            print("Missing conversion tools:")
            for tool in missing:
                print(f"  - {tool}")
            return False
        return True
        
    def command_exists(self, command):
        """Check if a command exists"""
        return subprocess.run(['which', command], 
                            capture_output=True, text=True).returncode == 0
                            
    def detect_file_format(self, file_path):
        """Detect actual file format from content"""
        try:
            with open(file_path, 'rb') as f:
                header = f.read(20)
                
            if header.startswith(b'PK') and (b'[Content_Types].xml' in open(file_path, 'rb').read(2000)):
                return 'xps'
            elif header.startswith(b'%PDF'):
                return 'pdf'
            elif header.startswith(b'%!PS'):
                return 'ps'
            elif header.startswith(b'\x1b'):
                return 'pcl'
            else:
                return 'text'
                
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return 'unknown'
            
    def convert_xps_to_pdf(self, input_file, output_file):
        """Convert XPS to PDF using xpstopdf"""
        try:
            result = subprocess.run(['xpstopdf', str(input_file), str(output_file)], 
                                  capture_output=True, text=True, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"XPS to PDF conversion failed: {e.stderr}")
            return False
            
    def convert_xps_to_png(self, input_file, output_dir):
        """Convert XPS to PNG images (one per page)"""
        try:
            # Create output directory for PNG pages
            png_dir = output_dir / f"{input_file.stem}_pages"
            png_dir.mkdir(exist_ok=True)
            
            # Convert to PDF first, then to PNG
            temp_pdf = output_dir / f"{input_file.stem}_temp.pdf"
            if self.convert_xps_to_pdf(input_file, temp_pdf):
                # Convert PDF to PNG pages
                result = subprocess.run([
                    'pdftoppm', '-png', str(temp_pdf), str(png_dir / 'page')
                ], capture_output=True, text=True)
                
                # Clean up temp PDF
                temp_pdf.unlink()
                
                if result.returncode == 0:
                    png_files = list(png_dir.glob('*.png'))
                    return len(png_files) > 0
                    
        except Exception as e:
            print(f"XPS to PNG conversion failed: {e}")
            
        return False
        
    def convert_ps_to_pdf(self, input_file, output_file):
        """Convert PostScript to PDF"""
        try:
            result = subprocess.run(['ps2pdf', str(input_file), str(output_file)], 
                                  capture_output=True, text=True, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"PS to PDF conversion failed: {e.stderr}")
            return False
            
    def convert_pcl_to_pdf(self, input_file, output_file):
        """Convert PCL to PDF using ghostscript"""
        try:
            result = subprocess.run([
                'gs', '-dNOPAUSE', '-dBATCH', '-sDEVICE=pdfwrite', 
                f'-sOutputFile={output_file}', str(input_file)
            ], capture_output=True, text=True, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"PCL to PDF conversion failed: {e.stderr}")
            return False
            
    def convert_file(self, input_file, output_format='pdf'):
        """Convert a single captured file"""
        input_path = Path(input_file)
        if not input_path.exists():
            print(f"File not found: {input_file}")
            return False
            
        # Detect actual format
        actual_format = self.detect_file_format(input_path)
        print(f"Converting {input_path.name} (detected as {actual_format}) to {output_format}")
        
        # Set up output file
        output_dir = input_path.parent / 'converted'
        output_dir.mkdir(exist_ok=True)
        
        if output_format == 'pdf':
            output_file = output_dir / f"{input_path.stem}.pdf"
        else:
            output_file = output_dir / f"{input_path.stem}.{output_format}"
            
        # Convert based on detected format
        success = False
        
        if actual_format == 'xps' and output_format == 'pdf':
            success = self.convert_xps_to_pdf(input_path, output_file)
        elif actual_format == 'xps' and output_format == 'png':
            success = self.convert_xps_to_png(input_path, output_dir)
        elif actual_format == 'ps' and output_format == 'pdf':
            success = self.convert_ps_to_pdf(input_path, output_file)
        elif actual_format == 'pcl' and output_format == 'pdf':
            success = self.convert_pcl_to_pdf(input_path, output_file)
        elif actual_format == 'pdf':
            print(f"File is already PDF format")
            return True
        elif actual_format == 'text':
            print(f"Text file - no conversion needed")
            return True
        else:
            print(f"Unsupported conversion: {actual_format} to {output_format}")
            return False
            
        if success:
            print(f"Converted: {output_file}")
            return True
        else:
            print(f"Conversion failed")
            return False
            
    def convert_directory(self, directory, output_format='pdf'):
        """Convert all files in a directory"""
        dir_path = Path(directory)
        if not dir_path.exists():
            print(f"Directory not found: {directory}")
            return
            
        # Find all captured files
        captured_files = []
        for pattern in ['*.xps', '*.ps', '*.pcl', '*.bin', '*.raw']:
            captured_files.extend(dir_path.glob(pattern))
            
        if not captured_files:
            print(f"No files to convert in {directory}")
            return
            
        print(f"Found {len(captured_files)} files to convert")
        
        successful = 0
        for file_path in captured_files:
            if self.convert_file(file_path, output_format):
                successful += 1
                
        print(f"Successfully converted {successful}/{len(captured_files)} files")
        
    def install_dependencies(self):
        """Install required conversion tools"""
        packages = [
            'libgxps-utils',     # xpstopdf
            'ghostscript',       # ps2pdf, gs
            'poppler-utils',     # pdftoppm
            'netpbm'            # pstopnm
        ]
        
        print("Installing conversion dependencies...")
        for package in packages:
            print(f"Installing {package}...")
            result = subprocess.run(['sudo', 'apt', 'install', '-y', package], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                print(f"  âœ“ {package} installed")
            else:
                print(f"  âœ— Failed to install {package}")

def main():
    parser = argparse.ArgumentParser(description='Convert captured print jobs to readable formats')
    parser.add_argument('path', nargs='?', default='captured_print_jobs',
                       help='File or directory to convert (default: captured_print_jobs)')
    parser.add_argument('-f', '--format', choices=['pdf', 'png'], default='pdf',
                       help='Output format (default: pdf)')
    parser.add_argument('--install-deps', action='store_true',
                       help='Install required conversion tools')
    parser.add_argument('--check-deps', action='store_true',
                       help='Check if conversion tools are installed')
    
    args = parser.parse_args()
    
    converter = PrintJobConverter()
    
    if args.install_deps:
        converter.install_dependencies()
        return 0
        
    if args.check_deps:
        if converter.check_dependencies():
            print("All conversion tools are available")
        return 0
        
    # Convert files
    path = Path(args.path)
    
    if path.is_file():
        converter.convert_file(path, args.format)
    elif path.is_dir():
        converter.convert_directory(path, args.format)
    else:
        print(f"Path not found: {args.path}")
        return 1
        
    return 0

if __name__ == '__main__':
    sys.exit(main())