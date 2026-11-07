# nowspinning.exe: runs the widget's own QML (../nowspinning) without
# Quickshell, which is Linux only. It brings the few Quickshell types the
# widget uses, and Windows' own media controls and audio in place of MPRIS
# and cava. Built on Windows for real; elsewhere it builds too, with no
# players and no audio, to try the QML side.
cmake_minimum_required(VERSION 3.21)

set(NOWSPINNING_VERSION "0.0.0" CACHE STRING "Version stamped on the program")
string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+" NOWSPINNING_VERSION_NUMBER "${NOWSPINNING_VERSION}")
if(NOT NOWSPINNING_VERSION_NUMBER)
    set(NOWSPINNING_VERSION_NUMBER "0.0.0")
endif()

project(nowspinning VERSION ${NOWSPINNING_VERSION_NUMBER} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick Network)

add_executable(nowspinning WIN32
    src/main.cpp
    src/quickshell.h src/quickshell.cpp
    src/panelwindow.h src/panelwindow.cpp
    src/io.h src/io.cpp
    src/mpris.h src/mpris.cpp
    src/media.h src/media.cpp
    src/audio.h src/audio.cpp
    src/spectrum.h src/spectrum.cpp
    src/host.h src/host.cpp
    shim.qrc
)

if(WIN32)
    target_sources(nowspinning PRIVATE src/media_windows.cpp src/audio_windows.cpp)
    configure_file(nowspinning.rc.in ${CMAKE_CURRENT_BINARY_DIR}/nowspinning.rc @ONLY)
    target_sources(nowspinning PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/nowspinning.rc)
    target_compile_definitions(nowspinning PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
    target_link_libraries(nowspinning PRIVATE windowsapp ole32 uuid)
    if(MSVC)
        # C++/WinRT wants exceptions with their full semantics, and its
        # headers are big.
        target_compile_options(nowspinning PRIVATE /EHsc /bigobj /permissive- /utf-8)
    endif()
else()
    target_sources(nowspinning PRIVATE src/media_other.cpp src/audio_other.cpp)
endif()

target_compile_definitions(nowspinning PRIVATE
    NOWSPINNING_VERSION="${NOWSPINNING_VERSION}"
    QT_NO_KEYWORDS)

target_link_libraries(nowspinning PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network)

install(TARGETS nowspinning RUNTIME DESTINATION .)
