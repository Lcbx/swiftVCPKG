#!bash

# requirements :
# - swift language sdk
# - CMAKE build system
# - ninja build system
# - vcpkg (dont forget to bootstrap)
# --- by default vcpkg dir is expected to be in same parent dir

export VCPKG_ROOT=$(ls -t -U | readlink -f ../vcpkg/)
export VCPKG_DEFAULT_TRIPLET=x64-windows
export VCPKG_TARGET_TRIPLET=x64-windows
PATH=$VCPKG_ROOT:$PATH
vcpkg install raylib
cmake  -G 'Ninja' -S . -B build #-DCMAKE_BUILD_TYPE=Debug

cd build 
ninja && ./swiftEngine.exe
