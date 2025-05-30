// Simple Arduino Test Template
// Includes Serial logging with placeholder for serial number
// Compatible with Arduino CLI in the provided app structure

#define SERIAL_NUMBER "{{SERIAL_NUMBER}}"

void setup() {
    // Initialize Serial communication at 115200 baud rate
    Serial.begin(115200);

    // Wait for Serial to initialize
    while (!Serial) {
        delay(100);
    }

    // Print initial log with serial number
    Serial.println("=== Arduino Test Template ===");
    Serial.print("Device Serial Number: ");
    Serial.println(SERIAL_NUMBER);
    Serial.println("Setup completed");
}

void loop() {
    // Print periodic log every 5 seconds
    Serial.println("Running loop...");
    Serial.print("Serial: ");
    Serial.println(SERIAL_NUMBER);
    Serial.println("Status: OK");
    delay(5000); // Wait 5 seconds before next log
}