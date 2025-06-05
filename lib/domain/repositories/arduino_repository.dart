abstract class ArduinoRepository {
  Future<bool> initialize();
  Future<bool> compileSketch(String sketchPath, String fqbn);
  Future<bool> uploadSketch(String sketchPath, String port, String fqbn);
  Future<List<String>> getAvailablePorts();
  Future<bool> installCore(String deviceType);
  Future<bool> installLibrary(String libraryName);
}
