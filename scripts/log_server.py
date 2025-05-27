import grpc
import time
import datetime
import random
from concurrent import futures
import threading

# Import the generated gRPC modules
# Note: You'll need to generate these first by running protoc
# The imports below assume you've already generated them
import log_service_pb2
import log_service_pb2_grpc

class LogServiceServicer(log_service_pb2_grpc.LogServiceServicer):
    """Implementation of the LogService service."""

    def StreamLogs(self, request, context):
        """Streams logs to the client."""
        print("New client connected to log stream")

        # Process steps for simulation
        steps = ["usbCheck", "compile", "flash", "error", "other"]
        levels = ["info", "warning", "error", "success"]
        devices = ["ESP32-001", "ESP32-002", "ESP8266-001", "ESP32-C3-001"]

        # Stream logs until client disconnects
        try:
            while context.is_active() and request.enable:
                # Generate a random log entry
                device_id = random.choice(devices)
                step = random.choice(steps)
                level = random.choice(levels)

                message = f"[{step.upper()}] Device {device_id}: "

                if step == "usbCheck":
                    message += "Checking USB connection"
                    if level == "error":
                        message += " - Failed to detect device"
                    elif level == "success":
                        message += " - Device connected successfully"

                elif step == "compile":
                    message += "Compiling firmware"
                    if level == "error":
                        message += " - Compilation error in main.cpp"
                    elif level == "warning":
                        message += " - Warning: Unused variable"
                    elif level == "success":
                        message += " - Compilation successful"

                elif step == "flash":
                    message += "Flashing firmware"
                    if level == "error":
                        message += " - Flash failed: Device disconnected"
                    elif level == "warning":
                        message += " - Warning: Flash verification skipped"
                    elif level == "success":
                        message += " - Flash completed successfully"

                elif step == "error":
                    message += "System error"
                    if level == "error":
                        message += " - Critical: Process terminated"
                    elif level == "warning":
                        message += " - Warning: Process unstable"

                else:
                    message += "Info: Process running"

                # Create response and send
                timestamp = datetime.datetime.now().isoformat()

                yield log_service_pb2.LogResponse(
                    message=message,
                    timestamp=timestamp,
                    level=level,
                    step=step,
                    deviceId=device_id
                )

                # Sleep for a random interval (1-5 seconds)
                time.sleep(random.uniform(1, 5))

        except grpc.RpcError as e:
            print(f"Client disconnected: {e}")

        print("Client disconnected from log stream")

def serve():
    """Start the gRPC server."""
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    log_service_pb2_grpc.add_LogServiceServicer_to_server(
        LogServiceServicer(), server)
    server.add_insecure_port('[::]:50051')
    server.start()
    print("Log gRPC server started on port 50051")
    server.wait_for_termination()

if __name__ == '__main__':
    serve()