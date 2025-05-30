// Simple Arduino Test Template
// Includes Serial logging with placeholder for serial number
// Compatible with Arduino CLI in the provided app structure

#define SERIAL_NUMBER "{{SERIAL_NUMBER}}"
unsigned long lastMillis = 0;
int counter = 0;

void setup() {
    // Initialize Serial communication at 115200 baud rate
    Serial.begin(115200);
    delay(1000); // Give serial port time to initialize

    // Print initial log with serial number
    Serial.println("=== Arduino Test Template ===");
    Serial.print("Device Serial Number: ");
    Serial.println(SERIAL_NUMBER);
    Serial.println("Setup completed");
}

void loop() {
    // Print more frequent logs (every second) with counter
    unsigned long currentMillis = millis();
    if (currentMillis - lastMillis >= 1000) {
        lastMillis = currentMillis;
        Serial.print("Time: ");
        Serial.print(currentMillis / 1000);
        Serial.print("s, Counter: ");
        Serial.print(counter++);
        Serial.print(", Serial: ");
        Serial.println(SERIAL_NUMBER);

        // Send a byte pattern to help debug serial issues
        Serial.write(0xAA);
        Serial.write(0x55);
        Serial.println();
    }
}