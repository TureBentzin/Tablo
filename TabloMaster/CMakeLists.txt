cmake_minimum_required(VERSION 3.10)
project(tablo)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB_RECURSE SOURCES "src/*.cpp" "src/*.h")

add_executable(tablo-master ${SOURCES})

# Link against the tabcrypt library
target_link_libraries(tablo-master PRIVATE tabcrypt)

install(TARGETS tablo-master DESTINATION bin)
