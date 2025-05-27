#!/bin/bash

# Exit on error
set -e

# Install required packages if not already installed
flutter pub global activate protoc_plugin

# Generate Dart code from proto files
mkdir -p lib/data/generated
protoc --dart_out=grpc:lib/data/generated -Iprotos protos/log_service.proto

echo "gRPC code generation completed successfully!"