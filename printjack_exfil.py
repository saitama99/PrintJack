#!/usr/bin/env python3
"""
Captured Print Jobs Data Exfiltration Server
"""

import os
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler

class FileServerHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=".", **kwargs)
    
    def do_GET(self):
        # Redirect root to converted folder
        if self.path == '/':
            self.send_response(302)
            self.send_header('Location', '/captured_print_jobs/converted/')
            self.end_headers()
            return
        
        # Use default behavior which calls our custom list_directory
        return super().do_GET()
    
    def list_directory(self, path):
        """Custom directory listing with better styling"""
        try:
            file_list = os.listdir(path)
        except OSError:
            self.send_error(404, "No permission to list directory")
            return None
        
        file_list.sort(key=lambda a: a.lower())
        
        # Create HTML response
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>PrintJack File Server</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }}
                .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                h1 {{ color: #333; text-align: center; margin-bottom: 30px; }}
                .file-list {{ list-style: none; padding: 0; }}
                .file-item {{ background: #f8f9fa; margin: 5px 0; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff; }}
                .file-item:hover {{ background: #e9ecef; }}
                .file-link {{ text-decoration: none; color: #333; font-weight: 500; }}
                .file-size {{ color: #666; font-size: 0.9em; float: right; }}
                .directory {{ border-left-color: #28a745; }}
                .directory .file-link {{ color: #28a745; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>PrintJack File Server</h1>
                <ul class="file-list">
        """
        
        # Check the URL path, not filesystem path
        url_path = self.path
        
        # Add parent directory link - hide when in captured_print_jobs folder
        if url_path != "/captured_print_jobs/" and url_path != "/":
            html_content += '''
                <li class="file-item directory">
                    <a href="../" class="file-link">.. (Parent Directory)</a>
                </li>
            '''
        
        for name in file_list:
            fullname = os.path.join(path, name)
            displayname = linkname = name
            
            # Handle directories
            if os.path.isdir(fullname):
                displayname = name + "/"
                linkname = name + "/"
                css_class = "file-item directory"
                icon = "[DIR]"
            else:
                css_class = "file-item"
                icon = "[FILE]"
                
            # Get file size
            try:
                size = os.path.getsize(fullname)
                if size < 1024:
                    size_str = f"{size} B"
                elif size < 1024**2:
                    size_str = f"{size/1024:.1f} KB"
                elif size < 1024**3:
                    size_str = f"{size/(1024**2):.1f} MB"
                else:
                    size_str = f"{size/(1024**3):.1f} GB"
            except:
                size_str = ""
            
            html_content += f'''
                <li class="{css_class}">
                    <a href="{linkname}" class="file-link">{icon} {displayname}</a>
                    <span class="file-size">{size_str}</span>
                </li>
            '''
        
        html_content += """
                </ul>
            </div>
        </body>
        </html>
        """
        
        # Send response
        encoded_content = html_content.encode('utf-8')
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded_content)))
        self.end_headers()
        self.wfile.write(encoded_content)
        return None

def get_local_ip():
    """Get the local IP address"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "localhost"

def main():
    # Create converted folder if it doesn't exist
    if not os.path.exists("captured_print_jobs/converted"):
        os.makedirs("captured_print_jobs/converted")
        with open("captured_print_jobs/converted/README.txt", "w") as f:
            f.write("Welcome to PrintJack File Server!\n")
            f.write("Click .. (Parent Directory) to go up folders.\n")
    
    # Try different ports
    ports_to_try = [80, 8080, 8000, 3000]
    server = None
    
    for port in ports_to_try:
        try:
            server = HTTPServer(('0.0.0.0', port), FileServerHandler)
            local_ip = get_local_ip()
            
            print("=" * 50)
            print("PrintJack File Server Started!")
            print("=" * 50)
            if port == 80:
                print(f"Access at: http://{local_ip}")
            else:
                print(f"Access at: http://{local_ip}:{port}")
            print("Defaults to: captured_print_jobs/converted/")
            print("Use .. (Parent Directory) to navigate up")
            print("Press Ctrl+C to stop")
            print("=" * 50)
            break
            
        except OSError as e:
            if "Address already in use" in str(e):
                print(f"Port {port} in use, trying next...")
                continue
            else:
                raise e
    
    if server is None:
        print("Could not find available port!")
        return
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")

if __name__ == "__main__":
    main()