@echo off
REM Script to generate Dart gRPC code from proto files

REM Ensure output directory exists
if not exist lib\data\generated mkdir lib\data\generated

REM Generate Dart code from proto files
protoc --dart_out=grpc:lib/data/generated -Iprotos protos/log_service.proto

echo "gRPC code generation completed successfully!"