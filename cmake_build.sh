#!bash

export VCPKG_ROOT=$(ls -t -U | readlink -f ../vcpkg/)
export VCPKG_DEFAULT_TRIPLET=x64-windows
export VCPKG_TARGET_TRIPLET=x64-windows
PATH=$VCPKG_ROOT:$PATH
vcpkg install raylib >/dev/null
cmake  -G 'Ninja' -S . -B build >/dev/null #-DCMAKE_BUILD_TYPE=Debug
#-DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
cd build 

#ninja -v \
ninja \
  && ./swiftEngine.exe >/dev/null
