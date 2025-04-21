cmake_minimum_required(VERSION 3.26)
project(raygui)

find_package(raylib CONFIG REQUIRED)

set(raygui_headers
    raygui.h
    )
set(raygui_sources
    raygui.c
    )
add_library(raygui ${raygui_sources} ${raygui_headers})
target_link_libraries(raygui PRIVATE raylib)