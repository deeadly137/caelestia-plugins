find_package(Qt6 REQUIRED COMPONENTS Test Qml)

add_executable(tst_plugins tst_plugins.cpp)

target_link_libraries(tst_plugins PRIVATE caelestia-plugins Qt6::Test Qt6::Qml Qt6::Quick)
target_include_directories(tst_plugins PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

add_test(NAME tst_plugins COMMAND tst_plugins)
set_tests_properties(tst_plugins PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
