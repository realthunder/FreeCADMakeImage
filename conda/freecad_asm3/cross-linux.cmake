# this one is important
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_PLATFORM Linux)

# specify the cross compiler
set(CMAKE_C_COMPILER $ENV{CC})
set(CMAKE_CXX_COMPILER $ENV{CXX})

# where is the target environment
set(CMAKE_FIND_ROOT_PATH $ENV{PREFIX} $ENV{BUILD_PREFIX}/$ENV{HOST}/sysroot)

# search for programs in the build host directories
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

find_program(QT_MOC_EXECUTABLE qt_moc moc PATHS ${BUILD_PREFIX}/bin NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH REQUIRED)
if (NOT TARGET Qt5::moc)
    add_executable(Qt5::moc IMPORTED)
endif ()
set_property(TARGET Qt5::moc PROPERTY IMPORTED_LOCATION ${QT_MOC_EXECUTABLE})

find_program(QT_RCC_EXECUTABLE qt_rcc rcc PATHS ${BUILD_PREFIX}/bin NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH REQUIRED)
if (NOT TARGET Qt5::rcc)
    add_executable(Qt5::rcc IMPORTED)
endif ()
set_property(TARGET Qt5::rcc PROPERTY IMPORTED_LOCATION ${QT_RCC_EXECUTABLE})

find_program(QT_UIC_EXECUTABLE qt_uic uic PATHS ${BUILD_PREFIX}/bin NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH REQUIRED)
if (NOT TARGET Qt5::uic)
    add_executable(Qt5::uic IMPORTED)
endif ()
set_property(TARGET Qt5::uic PROPERTY IMPORTED_LOCATION ${QT_UIC_EXECUTABLE})

find_program(QT_LRELEASE_EXECUTABLE qt_lrelease lrelease PATHS ${BUILD_PREFIX}/bin NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH REQUIRED)
if (NOT TARGET Qt5::lrelease)
    add_executable(Qt5::lrelease IMPORTED)
endif ()
set_property(TARGET Qt5::lrelease PROPERTY IMPORTED_LOCATION ${QT_LRELEASE_EXECUTABLE})
