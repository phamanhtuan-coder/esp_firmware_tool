#!/usr/bin/env python3
# ESP Firmware Flash Tool - Python Script

import os
import sys
import time
import logging
import argparse
import socketio
import json

# Add pyserial for USB port detection
try:
    import serial
    import serial.tools.list_ports
    SERIAL_AVAILABLE = True
except ImportError:
    SERIAL_AVAILABLE = False
    logging.warning("pyserial not installed. USB port detection will be disabled.")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("firmware_tool.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Socket.IO client setup
sio = socketio.Client()
connected = False

# Mock devices for testing
MOCK_DEVICES = [
    {
        "id": "esp32-001",
        "name": "ESP32 DevKit",
        "status": "connected",
        "serialNumber": "ESP32-ABC123",
        "firmwareVersion": "v1.0.0"
    },
    {
        "id": "esp8266-001",
        "name": "NodeMCU ESP8266",
        "status": "connected",
        "serialNumber": "ESP8266-XYZ789",
        "firmwareVersion": "v0.9.5"
    }
]

def get_serial_ports():
    """
    Get list of available serial ports with details

    Returns:
        List of dictionaries containing port information
    """
    if not SERIAL_AVAILABLE:
        logger.error("pyserial is not installed. Cannot detect USB ports.")
        return []

    ports = []
    try:
        for port in serial.tools.list_ports.comports():
            ports.append({
                "id": f"usb-{port.device.replace('/', '-').replace('\\', '-')}",
                "name": port.description if port.description else "Unknown Device",
                "status": "available",
                "serialNumber": port.serial_number if port.serial_number else None,
                "usbPort": port.device,
                "hwid": port.hwid,
                "vid": port.vid,
                "pid": port.pid,
            })
        return ports
    except Exception as e:
        logger.error(f"Error detecting serial ports: {e}")
        return []

def flash_firmware(device_id, template_path):
    """
    Flash firmware to the specified device using the template

    Args:
        device_id: The target device ID
        template_path: Path to the firmware template
    """
    if not os.path.exists(template_path):
        logger.error(f"Template file not found: {template_path}")
        sio.emit('status', 'error')
        return False

    logger.info(f"Flashing device {device_id} with template {template_path}")

    # Simulate the flashing process
    steps = ["Connecting to device", "Erasing flash", "Writing firmware", "Verifying", "Rebooting device"]

    for step in steps:
        logger.info(f"Step: {step}")
        sio.emit('status', f"Processing: {step}")
        time.sleep(1)  # Simulate processing time

    logger.info(f"Successfully flashed device {device_id}")
    sio.emit('status', 'completed')
    return True

@sio.event
def connect():
    global connected
    connected = True
    logger.info("Connected to Socket.IO server")
    sio.emit('status', 'idle')  # Initial status

@sio.event
def disconnect():
    global connected
    connected = False
    logger.info("Disconnected from Socket.IO server")

@sio.on('get_devices')
def on_get_devices():
    logger.info("Received request for device list")

    # Check for real USB devices if pyserial is available
    devices = get_serial_ports()

    # If no real devices found or in test mode, use mock devices
    if not devices:
        logger.warning("No USB devices found or pyserial not available, using mock devices")
        devices = MOCK_DEVICES

    sio.emit('devices', devices)

@sio.on('check_usb_connection')
def on_check_usb_connection(data):
    """
    Check if a specific serial device is connected

    Args:
        data: Dictionary containing serialNumber to check
    """
    logger.info(f"Checking USB connection for: {data}")
    serial_to_check = data.get('serialNumber')

    if not serial_to_check:
        logger.error("No serial number provided")
        sio.emit('usb_connection_result', {
            'success': False,
            'error': 'No serial number provided'
        })
        return

    devices = get_serial_ports()

    # Find matching device
    matching_devices = [d for d in devices if d.get('serialNumber') == serial_to_check]

    if matching_devices:
        logger.info(f"Device found: {matching_devices[0]}")
        sio.emit('usb_connection_result', {
            'success': True,
            'device': matching_devices[0]
        })
    else:
        logger.warning(f"No device found with serial number: {serial_to_check}")
        sio.emit('usb_connection_result', {
            'success': False,
            'error': f"No device found with serial number: {serial_to_check}"
        })

@sio.on('start_process')
def on_start_process(data):
    template_path = data.get('templatePath', None)
    logger.info(f"Received start process request with template: {template_path}")
    sio.emit('status', 'processing')

    # For testing, we'll just flash the first device
    if MOCK_DEVICES:
        flash_firmware(MOCK_DEVICES[0]['id'], template_path)
    else:
        logger.error("No devices available")
        sio.emit('status', 'error')

@sio.on('stop_process')
def on_stop_process():
    logger.info("Received stop process request")
    sio.emit('status', 'idle')

def main():
    parser = argparse.ArgumentParser(description='ESP Firmware Flash Tool')
    parser.add_argument('--server', default='http://localhost:3000', help='Socket.IO server URL')
    parser.add_argument('--list-ports', action='store_true', help='List available serial ports and exit')
    args = parser.parse_args()

    # Just list ports if requested
    if args.list_ports:
        ports = get_serial_ports()
        print(json.dumps(ports, indent=2))
        sys.exit(0)

    logger.info(f"Connecting to server: {args.server}")

    try:
        sio.connect(args.server)
        sio.wait()
    except Exception as e:
        logger.error(f"Error connecting to server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()