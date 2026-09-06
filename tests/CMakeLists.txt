cmake_minimum_required(VERSION 3.10)

find_package(Arrow REQUIRED)
find_package(Threads REQUIRED)

add_executable(tablo-tests
    test_main.cpp
    test_csv_manager.cpp
    test_master.cpp
    test_tabcrypt.cpp
    test_worker.cpp
    ../TabloNode/src/utils/csv_manager.cpp
    ../TabloNode/src/utils/worker.cpp
)

target_include_directories(tablo-tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/TabloNode/src/utils
    ${CMAKE_SOURCE_DIR}/TabloMaster/src/utils
)

target_link_libraries(tablo-tests PRIVATE
    Arrow::arrow_shared
    tabcrypt
    tablog
    tql
    ttp2
    Threads::Threads
)

add_test(NAME tablo.unit COMMAND tablo-tests)
set_tests_properties(tablo.unit PROPERTIES TIMEOUT 30)

install(TARGETS tablo-tests DESTINATION bin)
