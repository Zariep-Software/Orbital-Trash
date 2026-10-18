#!/usr/bin/env bash

set -euo pipefail

mkdir -p build/desktop

dub build --build=release

if [ -d "assets" ]; then
    cp -rv assets build/desktop/
else
    echo "Warning: 'assets' directory not found, skipping."
fi

cp -v *.x86_64 build/desktop/

echo "Done"