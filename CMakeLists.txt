cmake_minimum_required(VERSION 3.26)

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
  set(CMAKE_TOOLCHAIN_FILE
    "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
    CACHE STRING "")
endif()

message(STATUS "TOOLCHAIN: ${CMAKE_TOOLCHAIN_FILE}")

if(PROJECT_BINARY_DIR STREQUAL PROJECT_SOURCE_DIR)
  message(
    FATAL_ERROR
    "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there."
  )
endif()

set(CMAKE_OSX_DEPLOYMENT_TARGET 13.0)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
#set(BUILD_SHARED_LIBS OFF)

project(SwiftEngine LANGUAGES Swift CXX C)
set(CMAKE_EXE_LINKER_FLAGS_DISTRIBUTION "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")

set(VCPKG_INSTALLED "$ENV{VCPKG_ROOT}/installed/$ENV{VCPKG_TARGET_TRIPLET}")
message(STATUS "VCPKG_INSTALLED: ${VCPKG_INSTALLED}")

FILE(GLOB_RECURSE SRC_FILES sources/*.swift)
add_executable(swiftEngine ${SRC_FILES})
target_compile_options(swiftEngine PRIVATE -cxx-interoperability-mode=default)

if(CMAKE_BUILD_TYPE STREQUAL Debug)
  target_compile_options(swiftEngine PRIVATE -g -Onone -D DEBUG)
endif()


# general relevant linking for vcpkg
target_compile_options(swiftEngine PRIVATE -I ${VCPKG_INSTALLED}/include -L ${VCPKG_INSTALLED}/lib)

# using virtual file system to inject the modulemap
# based on https://www.swift.org/documentation/articles/wrapping-c-cpp-library-in-swift.html


function(add_vcpkg_dependency name)

  # some libs have their headers in a subdir
  if(EXISTS ${VCPKG_INSTALLED}/include/${name})
    set(INCLUDE_DIR ${VCPKG_INSTALLED}/include/${name})
    target_compile_options(swiftEngine PRIVATE -I ${VCPKG_INSTALLED}/include/${name})
  else()
    set(INCLUDE_DIR ${VCPKG_INSTALLED}/include)
  endif()

  target_compile_options(swiftEngine PRIVATE
    -Xlinker ${VCPKG_INSTALLED}/lib/${name}.lib )

  set("INCLUDE_DIR" ${INCLUDE_DIR})
  set("MODULEMAP_FILE" "${CMAKE_CURRENT_SOURCE_DIR}/deps/${name}.modulemap")

  set(VFS_FILE deps/${name}-vfs.yaml)
  configure_file(deps/module-vfs_template.yaml ${VFS_FILE})
  target_compile_options(swiftEngine PRIVATE
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-vfsoverlay ${VFS_FILE}>"
  )
endfunction()

add_vcpkg_dependency(raylib)
