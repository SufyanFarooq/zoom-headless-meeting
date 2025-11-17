cmake_minimum_required(VERSION 3.22.1)
project(meeting_sdk_linux_sample VERSION 1.0.2)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_COMPILER /usr/bin/g++)

set(CMAKE_BUILD_TYPE Debug)
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(ZOOM_SDK lib/zoomsdk)

# Try to find CLI11 via vcpkg first, fallback to system package
find_package(CLI11 QUIET)
if(NOT CLI11_FOUND)
    # If vcpkg fails, try pkg-config or header-only installation
    find_path(CLI11_INCLUDE_DIRS "CLI/CLI.hpp" PATHS /usr/include /usr/local/include)
    if(CLI11_INCLUDE_DIRS)
        message(STATUS "Found CLI11 via header-only: ${CLI11_INCLUDE_DIRS}")
        add_library(CLI11::CLI11 INTERFACE IMPORTED)
        set_target_properties(CLI11::CLI11 PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${CLI11_INCLUDE_DIRS}"
        )
    else()
        message(FATAL_ERROR "CLI11 not found. Please install via: apt-get install libcli11-dev or ensure vcpkg is working")
    endif()
endif()

find_path(PICOJSON_INCLUDE_DIRS "picojson/picojson.h")
find_path(JWT_CPP_INCLUDE_DIRS "jwt-cpp/base.h")

find_package(X11 REQUIRED)
include_directories(${X11_INCLUDE_DIR})
link_directories(${X11_LIBRARIES})

find_package(PkgConfig REQUIRED)
pkg_check_modules(deps REQUIRED IMPORTED_TARGET glib-2.0)

find_package( OpenCV REQUIRED )
include_directories( ${OpenCV_INCLUDE_DIRS} )

find_package(OpenSSL REQUIRED)

include_directories(${ZOOM_SDK}/h)
link_directories(${ZOOM_SDK} ${ZOOM_SDK})
link_directories(${ZOOM_SDK} ${ZOOM_SDK}/qt_libs/**)

add_executable(zoomsdk src/main.cpp
       src/Zoom.cpp
        src/Zoom.h
        src/Config.cpp
        src/Config.h
        src/util/Singleton.h
        src/util/Log.h
        src/events/AuthServiceEvent.cpp
        src/events/AuthServiceEvent.h
        src/events/MeetingServiceEvent.cpp
        src/events/MeetingServiceEvent.h
        src/events/MeetingReminderEvent.cpp
        src/events/MeetingReminderEvent.h
        src/events/MeetingRecordingCtrlEvent.cpp
        src/events/MeetingRecordingCtrlEvent.h
        src/raw_record/ZoomSDKAudioRawDataDelegate.cpp
        src/raw_record/ZoomSDKAudioRawDataDelegate.h
        src/raw_record/ZoomSDKRendererDelegate.cpp
        src/raw_record/ZoomSDKRendererDelegate.h
        src/raw_send/ZoomSDKVideoSource.h
        src/raw_send/ZoomSDKVideoSource.cpp
        src/util/SocketServer.h
        src/util/SocketServer.cpp
)

target_include_directories(zoomsdk PRIVATE ${JWT_CPP_INCLUDE_DIRS} ${PICOJSON_INCLUDE_DIRS})

# Link CLI11 conditionally - use vcpkg if available, otherwise header-only
if(TARGET CLI11::CLI11)
    target_link_libraries(zoomsdk PRIVATE meetingsdk OpenSSL::SSL OpenSSL::Crypto CLI11::CLI11 PkgConfig::deps ${OpenCV_LIBS} ${X11_LIBRARIES})
else()
    # Fallback: header-only CLI11 (already included via INTERFACE target)
    target_link_libraries(zoomsdk PRIVATE meetingsdk OpenSSL::SSL OpenSSL::Crypto PkgConfig::deps ${OpenCV_LIBS} ${X11_LIBRARIES})
endif()






