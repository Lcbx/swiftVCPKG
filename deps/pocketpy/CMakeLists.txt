cmake_minimum_required(VERSION 3.26)
project(pocketpy)

find_package(raylib CONFIG REQUIRED)

set(headers
    pocketpy.h
    )
set(sources
    pocketpy.c
    )
add_library(pocketpy ${sources} ${headers})