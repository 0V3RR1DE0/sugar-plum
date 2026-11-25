cmake_minimum_required(VERSION 3.16)
project(sugarplumcursor LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml Gui)

qt_standard_project_setup()

qt_add_qml_module(sugarplumcursor
    URI org.sugarplum.cursor
    VERSION 1.0
    SOURCES
        cursortracker.cpp
        cursortracker.h
)

target_link_libraries(sugarplumcursor PRIVATE Qt6::Quick Qt6::Qml Qt6::Gui)

install(TARGETS sugarplumcursor sugarplumcursorplugin
    LIBRARY DESTINATION lib/qt6/qml/org/sugarplum/cursor
)
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/sugarplumcursor.qmltypes
    DESTINATION lib/qt6/qml/org/sugarplum/cursor
)
