#!/usr/bin/env bash

set -euo pipefail

mkdir -p build/desktop

dub build -c windows --compiler=ldc2 --arch=x86_64-windows-msvc --build=release

if [ -d "assets" ]; then
    cp -rv assets build/desktop/
else
    echo "Warning: 'assets' directory not found, skipping."
fi

cp -v *.exe build/desktop/

echo "Done"