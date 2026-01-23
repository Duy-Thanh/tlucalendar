cmake_minimum_required(VERSION 3.22.1)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization flags for Low Memory / Size
# -Os: Simplify code, reduce binary size (good for instruction cache on low RAM)
# -fvisibility=hidden: Hide internal symbols to reduce export table size
# -ffunction-sections/-fdata-sections: Allow linker to strip unused code
add_compile_options(-O3 -fvisibility=hidden -ffunction-sections -fdata-sections)
add_link_options(-Wl,--gc-sections)


# Include Crashpad Build logic
include(crashpad.cmake)

add_library( 
        nekkoFramework
        SHARED
        yyjson.c
        native-lib.cpp
        crashpad_adapter.cpp) # Added adapter

find_library( 
        log-lib
        log)

target_link_libraries( 
        nekkoFramework
        ${log-lib}
        crashpad_client) # Link Client