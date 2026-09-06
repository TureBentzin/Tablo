cmake_minimum_required(VERSION 3.10)
project(tablo)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build options

option(DEF_LIBTABCRYPT "Build libtabcrypt" ON)

option(DEF_CLIENT "Build TabloClient" ON)
option(DEF_MASTER "Build TabloMaster" ON)
option(DEF_NODE "Build TabloNode" ON)
option(DEF_TESTS "Build the Tablo test suite" OFF)

# Shared libraries

if(DEF_LIBTABCRYPT)
    add_subdirectory(lib/libtabcrypt)
endif()

# Executables

if(DEF_CLIENT)
    add_subdirectory(TabloClient)
endif()

if(DEF_MASTER)
    add_subdirectory(TabloMaster)
endif()

if(DEF_NODE)
    add_subdirectory(TabloNode)
endif()

if(DEF_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
