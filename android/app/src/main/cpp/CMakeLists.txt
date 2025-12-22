cmake_minimum_required(VERSION 3.22.1)

add_library( 
        nekkoFramework
        SHARED
        native-lib.cpp)

find_library( 
        log-lib
        log)

target_link_libraries( 
        nekkoFramework
        ${log-lib})