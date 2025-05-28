/**************************************************************
 * ESP8266 + NeoPixel + Socket.IO Template
 *
 * Template version with placeholders for device configuration
 * Placeholders will be replaced by Flutter build tool:
 *  - {{DEVICE_ID}} - Device ID/Serial number
 *  - {{DEVICE_UUID}} - Unique device identifier
 *  - {{AP_SSID}} - Access Point SSID (based on serial)
 *  - {{DEFAULT_SSID}} - Default WiFi SSID
 *  - {{DEFAULT_PASSWORD}} - Default WiFi password
 *  - {{SERVER_HOST}} - Socket.IO server host
 *  - {{SERVER_PORT}} - Socket.IO server port
 **************************************************************/
#include <EEPROM.h>
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <SocketIoClient.h>
#include <ArduinoJson.h>
#include <Adafruit_NeoPixel.h>

// Device Configuration - Will be replaced by build tool
#define DEVICE_ID "{{DEVICE_ID}}"
#define DEVICE_UUID "{{DEVICE_UUID}}"
#define AP_SSID "{{AP_SSID}}"
#define DEFAULT_WIFI_SSID "{{DEFAULT_SSID}}"
#define DEFAULT_WIFI_PASSWORD "{{DEFAULT_PASSWORD}}"
#define SERVER_HOST "{{SERVER_HOST}}"
#define SERVER_PORT 3000  // Default port, will be replaced by build tool

// Version management
#define EEPROM_VERSION_ADDR 167
#define CURRENT_VERSION 3

// EEPROM Configuration
#define EEPROM_SIZE 512
#define SSID_ADDR 0
#define PASS_ADDR 64
#define SSID_MAX_LENGTH 32
#define PASS_MAX_LENGTH 64
#define LED_COLOR_ADDR 128
#define LED_BRIGHTNESS_ADDR 164
#define LED_POWER_ADDR 168

// WiFi and Connection Settings
const char* apPassword = "12345678";
const unsigned long WIFI_TIMEOUT = 20000;
const unsigned long RECONNECT_INTERVAL = 5000;

// UDP Configuration
WiFiUDP udp;
const unsigned int udpPort = 4210;
char incomingPacket[255];

// NeoPixel Configuration
#define LED_PIN 12  // GPIO12 (was D6)
#define NUMPIXELS 24
Adafruit_NeoPixel strip(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Socket.IO Configuration
String IO_PATH = "/device";
SocketIoClient socketIO;

// State Variables
bool ledPower = false;
String ledColor = "#FF0000";
int ledBrightness = 125;
bool isConnected = false;
unsigned long lastPingTime = 0;
unsigned long lastConnectAttempt = 0;

/**************************************************************
 * EEPROM Functions
 **************************************************************/
void readWiFiCredentials(String &ssid, String &password) {
    for (int i = 0; i < SSID_MAX_LENGTH; i++) {
        char c = EEPROM.read(SSID_ADDR + i);
        if (c == '\0') break;
        ssid += c;
    }

    for (int i = 0; i < PASS_MAX_LENGTH; i++) {
        char c = EEPROM.read(PASS_ADDR + i);
        if (c == '\0') break;
        password += c;
    }
}

void saveWiFiCredentials(const String &ssid, const String &password) {
    for (int i = 0; i < SSID_MAX_LENGTH; i++) {
        EEPROM.write(SSID_ADDR + i, 0);
    }
    for (int i = 0; i < PASS_MAX_LENGTH; i++) {
        EEPROM.write(PASS_ADDR + i, 0);
    }

    for (int i = 0; i < ssid.length(); i++) {
        EEPROM.write(SSID_ADDR + i, ssid[i]);
    }
    for (int i = 0; i < password.length(); i++) {
        EEPROM.write(PASS_ADDR + i, password[i]);
    }

    EEPROM.commit();
}

void readLEDState() {
    if (EEPROM.read(EEPROM_VERSION_ADDR) != CURRENT_VERSION) {
        resetEEPROM();
        return;
    }

    String color = "";
    for (int i = 0; i < 7; i++) {
        char c = EEPROM.read(LED_COLOR_ADDR + i);
        if (c != 0) color += c;
    }
    ledColor = color.length() == 7 ? color : "#FF0000";

    ledBrightness = EEPROM.read(LED_BRIGHTNESS_ADDR);
    ledPower = EEPROM.read(LED_POWER_ADDR) == 1;
}

void saveLEDState() {
    for (int i = 0; i < 7; i++) {
        EEPROM.write(LED_COLOR_ADDR + i, ledColor[i]);
    }

    EEPROM.write(LED_BRIGHTNESS_ADDR, ledBrightness);
    EEPROM.write(LED_POWER_ADDR, ledPower ? 1 : 0);
    EEPROM.commit();
}

void resetEEPROM() {
    for (int i = 0; i < EEPROM_SIZE; i++) {
        EEPROM.write(i, 0);
    }
    EEPROM.write(EEPROM_VERSION_ADDR, CURRENT_VERSION);
    EEPROM.commit();

    ledColor = "#FFFFFF";
    ledBrightness = 100;
    ledPower = false;
    saveLEDState();
}

/**************************************************************
 * LED Control Functions
 **************************************************************/
uint32_t hexToColor(String hex) {
    if (hex.charAt(0) != '#' || hex.length() != 7) return strip.Color(0, 0, 0);
    long number = strtol(&hex[1], NULL, 16);
    return strip.Color((number >> 16) & 0xFF, (number >> 8) & 0xFF, number & 0xFF);
}

void setAllPixels(uint32_t color) {
    for (int i = 0; i < NUMPIXELS; i++) {
        strip.setPixelColor(i, color);
    }
    strip.show();
}

void updateLED() {
    int brightnessScaled = map(ledBrightness, 0, 100, 0, 255);
    strip.setBrightness(brightnessScaled);

    if (!ledPower) {
        strip.clear();
        strip.show();
        return;
    }

    setAllPixels(hexToColor(ledColor));
    strip.show();
}

void handleLEDStatus(String status) {
    if (status == "CONNECTING") {
        setAllPixels(hexToColor("#FFD700"));
    } else if (status == "CONNECTED") {
        setAllPixels(hexToColor("#008001"));
        delay(3000);
        updateLED();
    } else if (status == "FAILED") {
        setAllPixels(hexToColor("#FF0000"));
        delay(3000);
        strip.clear();
        strip.show();
    } else {
        strip.clear();
        strip.show();
    }
}

/**************************************************************
 * Network Functions
 **************************************************************/
void setupAccessPoint() {
    WiFi.softAP(AP_SSID, apPassword);
    Serial.println("[AP] Access Point created:");
    Serial.print("SSID: ");
    Serial.println(AP_SSID);
    Serial.print("Password: ");
    Serial.println(apPassword);
    Serial.print("Device ID: ");
    Serial.println(DEVICE_ID);
    Serial.print("Device UUID: ");
    Serial.println(DEVICE_UUID);
}

void setupUDP() {
    udp.begin(udpPort);
    Serial.println("[UDP] Listening on port " + String(udpPort));
}

bool connectToWiFi(const String &ssid, const String &password) {
    if (WiFi.status() == WL_CONNECTED) {
        WiFi.disconnect();
    }

    handleLEDStatus("CONNECTING");
    Serial.println("[WiFi] Connecting to: " + ssid);
    WiFi.begin(ssid.c_str(), password.c_str());

    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED) {
        if (millis() - startTime > WIFI_TIMEOUT) {
            handleLEDStatus("FAILED");
            Serial.println("[WiFi] Connection failed");
            return false;
        }
        delay(500);
        Serial.print(".");
    }

    Serial.println("\n[WiFi] Connected successfully");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    handleLEDStatus("CONNECTED");
    saveWiFiCredentials(ssid, password);
    return true;
}

/**************************************************************
 * UDP Message Handling
 **************************************************************/
String parseValue(String data, String key) {
    int startIndex = data.indexOf(key + "=");
    if (startIndex == -1) return "";
    startIndex += key.length() + 1;
    int endIndex = data.indexOf(";", startIndex);
    return endIndex == -1 ? data.substring(startIndex) : data.substring(startIndex, endIndex);
}

void handleUDPMessage() {
    int packetSize = udp.parsePacket();
    if (packetSize) {
        int len = udp.read(incomingPacket, 255);
        if (len > 0) {
            incomingPacket[len] = '\0';
            String receivedData = String(incomingPacket);
            Serial.println("[UDP] Received: " + receivedData);

            String ssid = parseValue(receivedData, "SSID");
            String password = parseValue(receivedData, "PASSWORD");
            if (!ssid.isEmpty() && !password.isEmpty()) {
                if (connectToWiFi(ssid, password)) {
                    startSocketIO();
                }
            }
        }
    }
}

/**************************************************************
 * Socket.IO Functions
 **************************************************************/
// Function declarations
void onConnectEvent(const char* payload, size_t length);
void onDisconnectEvent(const char* payload, size_t length);
void onCommandEvent(const char* payload, size_t length);

// Handle Socket.IO events with the correct function signature
void onSocketEvent(const char* event, const char* payload, size_t length) {
    Serial.printf("[IO] event: %s, payload: %s\n", event, payload);

    if (strcmp(event, "command") == 0) {
        DynamicJsonDocument doc(512);
        DeserializationError err = deserializeJson(doc, payload);
        if (err) {
            Serial.println("[IO] JSON parse error");
            return;
        }

        String action = doc["action"] | "";

        if (action == "toggle") {
            ledPower = doc["powerStatus"] | false;
            ledColor = doc["color"] | "#FFFFFF";
            ledBrightness = doc["brightness"] | 100;
            updateLED();
            saveLEDState();
            Serial.printf("[IO] Toggle LED -> Power=%s, Color=%s, Brightness=%d\n",
                          (ledPower ? "ON" : "OFF"), ledColor.c_str(), ledBrightness);
        } else if (action == "updateAttributes") {
            ledPower = true;
            ledColor = doc["color"] | "#FFFFFF";
            ledBrightness = doc["brightness"] | 100;
            updateLED();
            saveLEDState();
            Serial.printf("[IO] Update attributes -> Power=%s, Color=%s, Brightness=%d\n",
                          (ledPower ? "ON" : "OFF"), ledColor.c_str(), ledBrightness);
        } else if (action == "updateWifi") {
            String newSSID = doc["WifiSSID"];
            String newPass = doc["WifiPassword"];
            if (newSSID.length() > 0 && newPass.length() > 0) {
                saveWiFiCredentials(newSSID, newPass);
                Serial.println("[IO] WiFi credentials updated, restarting...");
                delay(1000);
                ESP.restart();
            }
        }
    }

    if (strcmp(event, "connect") == 0) {
        isConnected = true;
        Serial.println("[IO] Connected to server");

        // Send device info with UUID
        String deviceInfo = "{\"deviceId\":\"" + String(DEVICE_ID) + "\",\"uuid\":\"" + String(DEVICE_UUID) + "\"}";
        socketIO.emit("device_online", deviceInfo.c_str());
    }

    if (strcmp(event, "disconnect") == 0) {
        isConnected = false;
        Serial.println("[IO] Disconnected from server");
    }
}

// Handler for connect events with signature expected by SocketIoClient
void onConnectEvent(const char* payload, size_t length) {
    onSocketEvent("connect", payload, length);
}

// Handler for disconnect events with signature expected by SocketIoClient
void onDisconnectEvent(const char* payload, size_t length) {
    onSocketEvent("disconnect", payload, length);
}

// Handler for command events with signature expected by SocketIoClient
void onCommandEvent(const char* payload, size_t length) {
    onSocketEvent("command", payload, length);
}

void startSocketIO() {
    String url = IO_PATH + "?deviceId=" + String(DEVICE_ID) + "&uuid=" + String(DEVICE_UUID);
    socketIO.beginSSL(SERVER_HOST, SERVER_PORT, url.c_str());
    socketIO.on("connect", onConnectEvent);
    socketIO.on("disconnect", onDisconnectEvent);
    socketIO.on("command", onCommandEvent);

    Serial.println("[IO] Connecting to Socket.IO server...");
    Serial.println("[IO] Server: " + String(SERVER_HOST) + ":" + String(SERVER_PORT));
    Serial.println("[IO] Device ID: " + String(DEVICE_ID));
    Serial.println("[IO] Device UUID: " + String(DEVICE_UUID));
    handleLEDStatus("CONNECTING");

    unsigned long startTime = millis();
    while (!isConnected && millis() - startTime < 10000) {
        socketIO.loop();
        delay(100);
    }

    lastConnectAttempt = millis();

    if (isConnected) {
        Serial.println("[IO] Socket.IO connected successfully!");
        handleLEDStatus("CONNECTED");
    } else {
        Serial.println("[IO] Socket.IO connection failed!");
        handleLEDStatus("FAILED");
    }
}

/**************************************************************
 * SETUP
 **************************************************************/
void setup() {
    Serial.begin(115200);
    Serial.println("\n\n[BOOT] Starting ESP8266 + Socket.IO + NeoPixel");
    Serial.println("[BOOT] Device ID: " + String(DEVICE_ID));
    Serial.println("[BOOT] Device UUID: " + String(DEVICE_UUID));

    EEPROM.begin(EEPROM_SIZE);
    readLEDState();

    strip.begin();
    strip.show();
    strip.clear();

    String storedSSID = "", storedPassword = "";
    readWiFiCredentials(storedSSID, storedPassword);

    if (!storedSSID.isEmpty() && !storedPassword.isEmpty()) {
        Serial.println("[BOOT] Attempting to connect with stored credentials");
        if (connectToWiFi(storedSSID, storedPassword)) {
            startSocketIO();
            return;
        }
    }

    Serial.println("[BOOT] Attempting to connect with default credentials");
    if (connectToWiFi(DEFAULT_WIFI_SSID, DEFAULT_WIFI_PASSWORD)) {
        startSocketIO();
        return;
    }

    setupAccessPoint();
    setupUDP();
}

/**************************************************************
 * LOOP
 **************************************************************/
void loop() {
    if (WiFi.status() != WL_CONNECTED) {
        handleUDPMessage();
    } else {
        if (isConnected) {
            socketIO.loop();

            unsigned long currentTime = millis();
            if (currentTime - lastPingTime > 15000) {
                socketIO.emit("ping", "");
                lastPingTime = currentTime;
            }
        } else {
            unsigned long currentTime = millis();
            if (currentTime - lastConnectAttempt > RECONNECT_INTERVAL) {
                startSocketIO();
                lastConnectAttempt = currentTime;
            }
        }
    }
}