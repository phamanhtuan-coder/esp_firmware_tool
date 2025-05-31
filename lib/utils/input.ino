#define SERIAL_NUMBER "{{SERIAL_NUMBER}}"
void setup() {
  Serial.begin(115200);
  Serial.println(SERIAL_NUMBER);
}
void loop() {}