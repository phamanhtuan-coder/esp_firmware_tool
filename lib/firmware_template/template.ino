// Simple Arduino Test Template
// Includes Serial logging with placeholder for serial number
// Compatible with Arduino CLI in the provided app structure

// BOARD_TYPE: ESP32
// Uncomment the board type you want to use:
// BOARD_TYPE: ESP8266
// BOARD_TYPE: ARDUINO_UNO
// BOARD_TYPE: ARDUINO_MEGA
// BOARD_TYPE: ARDUINO_NANO
// BOARD_TYPE: ARDUINO_UNO_R3 (ACTIVE)

// Always use quotes for serial number and device ID to avoid compiler errors
#define SERIAL_NUMBER "{{SERIAL_NUMBER}}"
#define DEVICE_ID "{{DEVICE_ID}}"

// Board-specific configurations
#if defined(ESP32)
  #include <WiFi.h>
  #define BOARD_NAME "ESP32"
  #define LED_PIN 2
#elif defined(ESP8266)
  #include <ESP8266WiFi.h>
  #define BOARD_NAME "ESP8266"
  #define LED_PIN 2
#elif defined(ARDUINO_AVR_UNO) || defined(ARDUINO_UNO_R3)
  #define BOARD_NAME "Arduino UNO"
  #define LED_PIN 13
#elif defined(ARDUINO_AVR_MEGA2560)
  #define BOARD_NAME "Arduino MEGA"
  #define LED_PIN 13
#elif defined(ARDUINO_AVR_NANO)
  #define BOARD_NAME "Arduino NANO"
  #define LED_PIN 13
#else
  #define BOARD_NAME "Unknown Board"
  #define LED_PIN 13
#endif

unsigned long lastMillis = 0;
int counter = 0;

void setup() {
    // Initialize Serial communication at 115200 baud rate
    Serial.begin(115200);
    delay(1000); // Give serial port time to initialize

    // Configure LED
    pinMode(LED_PIN, OUTPUT);

    // Print initial log with serial number
    Serial.println("=== Arduino Test Template ===");
    Serial.print("Board Type: ");
    Serial.println(BOARD_NAME);
    Serial.print("Device Serial Number: ");
    Serial.println(SERIAL_NUMBER);
    Serial.print("Device ID: ");
    Serial.println(DEVICE_ID);
    Serial.println("Setup completed");
}

void loop() {
    // Print more frequent logs (every second) with counter
    unsigned long currentMillis = millis();
    if (currentMillis - lastMillis >= 1000) {
        lastMillis = currentMillis;

        // Toggle LED
        digitalWrite(LED_PIN, !digitalRead(LED_PIN));

        Serial.print("Time: ");
        Serial.print(currentMillis / 1000);
        Serial.print("s, Counter: ");
        Serial.print(counter++);
        Serial.print(", Board: ");
        Serial.print(BOARD_NAME);
        Serial.print(", Serial: ");
        Serial.println(SERIAL_NUMBER);

        // Send a byte pattern to help debug serial issues
        Serial.write(0xAA);
        Serial.write(0x55);
        Serial.println();
    }
}
