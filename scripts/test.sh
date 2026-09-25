#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks
swiftc Sources/BeastPanorama/Pose.swift Sources/BeastPanorama/SDK.swift Tests/Smoke/main.swift -o .build/checks/pose-tests
.build/checks/pose-tests
