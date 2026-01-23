# Crashpad CMake Build Setup

set(CRASHPAD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/crashpad")
set(MINI_CHROMIUM_DIR "${CRASHPAD_DIR}/third_party/mini_chromium/mini_chromium")

include_directories(
    "${MINI_CHROMIUM_DIR}"
    "${CRASHPAD_DIR}"
    "${CRASHPAD_DIR}/compat/android"
    "${CRASHPAD_DIR}/compat/linux"
    "${CRASHPAD_DIR}/compat/non_win"
)

# Find system libraries
find_library(LOG_LIB log)
find_library(Z_LIB z)

# --- Mini Chromium Base ---
file(GLOB_RECURSE MINI_CHROMIUM_SOURCES "${MINI_CHROMIUM_DIR}/base/*.cc")
# Filter out Mac/Win specific files
list(FILTER MINI_CHROMIUM_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER MINI_CHROMIUM_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER MINI_CHROMIUM_SOURCES EXCLUDE REGEX "(_test|_test_util)\\.cc$")

list(FILTER MINI_CHROMIUM_SOURCES EXCLUDE REGEX "(_test|_test_util)\\.cc$")

# Check sources
list(LENGTH MINI_CHROMIUM_SOURCES MINI_CHROMIUM_LEN)
if(MINI_CHROMIUM_LEN EQUAL 0)
    message(FATAL_ERROR "No Mini Chromium sources found in ${MINI_CHROMIUM_DIR}/base")
else()
    message(STATUS "Found ${MINI_CHROMIUM_LEN} Mini Chromium source files")
endif()

add_library(mini_chromium STATIC ${MINI_CHROMIUM_SOURCES})
target_compile_definitions(mini_chromium PUBLIC -D__ANDROID__)
add_definitions(-DCRASHPAD_LSS_SOURCE_EMBEDDED) # Tell Crashpad to look for LSS in third_party/lss/lss
add_definitions(-DCRASHPAD_ZLIB_SOURCE_SYSTEM) # Use Android NDK's system zlib
target_link_libraries(mini_chromium ${LOG_LIB})

# --- Crashpad Compat ---
file(GLOB_RECURSE CRASHPAD_COMPAT_SOURCES "${CRASHPAD_DIR}/compat/*.cc")
list(FILTER CRASHPAD_COMPAT_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_COMPAT_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER CRASHPAD_COMPAT_SOURCES EXCLUDE REGEX "(_test|_test_util)\\.cc$")
add_library(crashpad_compat STATIC ${CRASHPAD_COMPAT_SOURCES})

# --- Crashpad Util ---
file(GLOB_RECURSE CRASHPAD_UTIL_SOURCES "${CRASHPAD_DIR}/util/*.cc")
list(FILTER CRASHPAD_UTIL_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_UTIL_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
# Exclude tests
list(FILTER CRASHPAD_UTIL_SOURCES EXCLUDE REGEX "_test(|_main|_util|_util_linux)\\.cc$")
list(FILTER CRASHPAD_UTIL_SOURCES EXCLUDE REGEX "http_transport_libcurl\\.cc$")

add_library(crashpad_util STATIC ${CRASHPAD_UTIL_SOURCES})
target_link_libraries(crashpad_util mini_chromium crashpad_compat ${Z_LIB}) # Link system zlib

# ... (omitted) line removed
# premature target_link_libraries removed

# --- Crashpad Client ---
file(GLOB_RECURSE CRASHPAD_CLIENT_SOURCES "${CRASHPAD_DIR}/client/*.cc")
list(FILTER CRASHPAD_CLIENT_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_CLIENT_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER CRASHPAD_CLIENT_SOURCES EXCLUDE REGEX "_test(|_main)\\.cc$")

add_library(crashpad_client STATIC ${CRASHPAD_CLIENT_SOURCES})
target_link_libraries(crashpad_client crashpad_util)

# --- Crashpad Handler (Executable as .so) ---
file(GLOB_RECURSE CRASHPAD_HANDLER_SOURCES "${CRASHPAD_DIR}/handler/*.cc")
list(FILTER CRASHPAD_HANDLER_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_HANDLER_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER CRASHPAD_HANDLER_SOURCES EXCLUDE REGEX "_test(|_main)\\.cc$")

# Common snapshot/minidump sources needed by handler
file(GLOB_RECURSE CRASHPAD_SNAPSHOT_SOURCES "${CRASHPAD_DIR}/snapshot/*.cc")
list(FILTER CRASHPAD_SNAPSHOT_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_SNAPSHOT_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER CRASHPAD_SNAPSHOT_SOURCES EXCLUDE REGEX "_test(|_main)\\.cc$")

file(GLOB_RECURSE CRASHPAD_MINIDUMP_SOURCES "${CRASHPAD_DIR}/minidump/*.cc")
list(FILTER CRASHPAD_MINIDUMP_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_MINIDUMP_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER CRASHPAD_MINIDUMP_SOURCES EXCLUDE REGEX "_test(|_main)\\.cc$")

# Tool support
file(GLOB_RECURSE CRASHPAD_TOOLS_SOURCES "${CRASHPAD_DIR}/tools/*.cc")
list(FILTER CRASHPAD_TOOLS_SOURCES EXCLUDE REGEX "(_mac|_win|_fuchsia)\\.cc$")
list(FILTER CRASHPAD_TOOLS_SOURCES EXCLUDE REGEX "/mac/|/win/|/fuchsia/|/apple/|/ios/|/mach/")
list(FILTER CRASHPAD_TOOLS_SOURCES EXCLUDE REGEX "_test(|_main)\\.cc$")

add_executable(crashpad_handler 
    ${CRASHPAD_HANDLER_SOURCES}
    ${CRASHPAD_SNAPSHOT_SOURCES}
    ${CRASHPAD_MINIDUMP_SOURCES}
    ${CRASHPAD_TOOLS_SOURCES}
)

target_link_libraries(crashpad_handler crashpad_client crashpad_util mini_chromium crashpad_compat ${LOG_LIB})

# Rename to libcrashpad_handler.so so Android extracts it
set_target_properties(crashpad_handler PROPERTIES OUTPUT_NAME "crashpad_handler")
set_target_properties(crashpad_handler PROPERTIES SUFFIX ".so")
