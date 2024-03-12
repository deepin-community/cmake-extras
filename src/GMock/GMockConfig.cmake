# Copyright (C) 2014 Canonical Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Build with system gmock and embedded gtest
#
# Usage:
#
# # Optional, only if your usecase requires shared libs GMock
# set(GMOCK_BUILD_SHARED_LIBS ON)
# find_package(GMock)
#
# ...
#
# target_link_libraries(
#   my-target
#   ${GTEST_BOTH_LIBRARIES}
# )
#
# This also provides the following variables, with the version of the found gtest.
# These are both set as c/c++ definitions and cmake varables
#
# GTEST_VERSION_MAJOR
# GTEST_VERSION_MINOR
# GTEST_VERSION_PATCH
#
# NOTE: Due to the way this package finder is implemented, do not attempt
# to find the GMock package more than once.

macro(add_gtest_version_defines)
  # get a gtest version string that the regex will match
  pkg_check_modules(GTEST_PKGCONFIG "gtest")
  if (GTEST_PKGCONFIG_FOUND)
    set(GTEST_VERSION_STR ${GTEST_PKGCONFIG_VERSION})
    set(GTEST_DETECTION_METHOD "pkg-config")
  elseif (DEFINED ENV{GTEST_VERSION})
    set(GTEST_VERSION_STR $ENV{GTEST_VERSION})
    set(GTEST_DETECTION_METHOD "GTEST_VERSION environment variable")
  else()
    message(WARNING "Could not detect GTest version, Assuming v${GTEST_VERSION_STR} (or compatible) and hoping for the best")
    add_definitions(-DGTEST_VERSION_UNKNOWN)
    set(GTEST_DETECTION_METHOD "best guess, could not detect")
  endif()

  string(REGEX MATCH
    "([0-9]+)\\.([0-9]+)\\.([0-9]+)" GTEST_VERSION_PARSED
    ${GTEST_VERSION_STR})
  if (GTEST_VERSION_PARSED)
    set(GTEST_VERSION_MAJOR ${CMAKE_MATCH_1})
    set(GTEST_VERSION_MINOR ${CMAKE_MATCH_2})
    set(GTEST_VERSION_PATCH ${CMAKE_MATCH_3})
    message("-- Using GTest v${GTEST_VERSION_MAJOR}.${GTEST_VERSION_MINOR}.${GTEST_VERSION_PATCH} (parsed from ${GTEST_DETECTION_METHOD})")
  else()
    # fallback to 1.8.0
    message(WARNING "Could not parse GTest version: ${GTEST_VERSION_STR} (${GTEST_DETECTION_METHOD}), Assuming v1.8.0 (or compatible) and hoping for the best")
    set(GTEST_VERSION_MAJOR 1)
    set(GTEST_VERSION_MINOR 8)
    set(GTEST_VERSION_PATCH 0)
    add_definitions(-DGTEST_VERSION_UNKNOWN)
  endif()

  add_definitions(-DGTEST_VERSION_MAJOR=${GTEST_VERSION_MAJOR})
  add_definitions(-DGTEST_VERSION_MINOR=${GTEST_VERSION_MINOR})
  add_definitions(-DGTEST_VERSION_PATCH=${GTEST_VERSION_PATCH})
endmacro()

find_package(Threads)
find_package(PkgConfig)

if (EXISTS "/usr/src/googletest/googlemock" AND EXISTS "/usr/src/googletest/googletest")
    set(GMOCK_SOURCE_DIR "/usr/src/googletest/googlemock" CACHE PATH "gmock source directory")
    set(GMOCK_INCLUDE_DIRS "${GMOCK_SOURCE_DIR}/include" CACHE PATH "gmock source include directory")
    set(GTEST_INCLUDE_DIRS "/usr/src/googletest/googletest/include" CACHE PATH "gtest source include directory")
    set(GTEST_VERSION_STR "1.8.0")
elseif(EXISTS "/usr/src/gmock")
    # fallback
    set(GMOCK_SOURCE_DIR "/usr/src/gmock" CACHE PATH "gmock source directory")
    set(GMOCK_INCLUDE_DIRS "/usr/include" CACHE PATH "gmock source include directory")
    set(GTEST_INCLUDE_DIRS "/usr/include" CACHE PATH "gtest source include directory")
    set(GTEST_VERSION_STR "1.7.0")
else()
    # Try using CMake targets provided by GTest
    find_package (GTest)
    if(GTest_FOUND AND TARGET GTest::gmock)
        set(GTEST_LIBRARIES GTest::gtest)
        set(GTEST_MAIN_LIBRARIES GTest::gtest_main)
        set(GMOCK_LIBRARIES GTest::gmock_main GTest::gmock)
        set(GTEST_BOTH_LIBRARIES ${GTEST_LIBRARIES} ${GTEST_MAIN_LIBRARIES})

        add_gtest_version_defines()
        return()
    endif()

    set(GMock_FOUND FALSE)
    return()
endif()
message("-- Using ${GMOCK_SOURCE_DIR}/ as gmock source directory")

add_gtest_version_defines()

# We add -g so we get debug info for the gtest stack frames with gdb.
# The warnings are suppressed so we get a noise-free build for gtest and gmock if the caller
# has these warnings enabled.
set(findgmock_cxx_flags "${CMAKE_CXX_FLAGS} -g -Wno-old-style-cast -Wno-missing-field-initializers -Wno-ctor-dtor-privacy -Wno-switch-default")

set(findgmock_bin_dir "${CMAKE_CURRENT_BINARY_DIR}/gmock")

if ("${GTEST_VERSION_MAJOR}.${GTEST_VERSION_MINOR}.${GTEST_VERSION_PATCH}" VERSION_LESS "1.8.1")
    set(findgmock_gtest_libdir "${findgmock_bin_dir}/gtest")
    set(findgmock_gmock_libdir "${findgmock_bin_dir}")
else()
    set(findgmock_gtest_libdir "${findgmock_bin_dir}/lib")
    set(findgmock_gmock_libdir "${findgmock_bin_dir}/lib")
endif()

if (GMOCK_BUILD_SHARED_LIBS)
    message(STATUS "Building GMock as shared libraries.")
    set(findgmock_lib_suffix ".so")
    set(findgmock_lib_type SHARED)
else()
    set(findgmock_lib_suffix ".a")
    set(findgmock_lib_type STATIC)
endif()

set(findgmock_gtest_lib "${findgmock_gtest_libdir}/libgtest${findgmock_lib_suffix}")
set(findgmock_gtest_main_lib "${findgmock_gtest_libdir}/libgtest_main${findgmock_lib_suffix}")
set(findgmock_gmock_lib "${findgmock_gmock_libdir}/libgmock${findgmock_lib_suffix}")
set(findgmock_gmock_main_lib "${findgmock_gmock_libdir}/libgmock_main${findgmock_lib_suffix}")

include(ExternalProject)
ExternalProject_Add(GMock SOURCE_DIR "${GMOCK_SOURCE_DIR}"
                          BINARY_DIR "${findgmock_bin_dir}"
                          BUILD_BYPRODUCTS "${findgmock_gtest_lib}"
                                           "${findgmock_gtest_main_lib}"
                                           "${findgmock_gmock_main_lib}"
                                           "${findgmock_gmock_lib}"
                          INSTALL_COMMAND ""
                          CMAKE_ARGS "-DCMAKE_CXX_FLAGS=${findgmock_cxx_flags}" -DBUILD_SHARED_LIBS=${GMOCK_BUILD_SHARED_LIBS})

add_library(gtest ${findgmock_lib_type} IMPORTED)
set_property(TARGET gtest PROPERTY IMPORTED_LOCATION ${findgmock_gtest_lib})
target_include_directories(gtest INTERFACE ${GTEST_INCLUDE_DIRS})
target_link_libraries(gtest INTERFACE ${CMAKE_THREAD_LIBS_INIT})
add_dependencies(gtest GMock)

add_library(gtest_main ${findgmock_lib_type} IMPORTED)
set_property(TARGET gtest_main PROPERTY IMPORTED_LOCATION ${findgmock_gtest_main_lib})
target_include_directories(gtest_main INTERFACE ${GTEST_INCLUDE_DIRS})
target_link_libraries(gtest_main INTERFACE gtest)

add_library(gmock ${findgmock_lib_type} IMPORTED)
set_property(TARGET gmock PROPERTY IMPORTED_LOCATION ${findgmock_gmock_lib})
target_include_directories(gmock INTERFACE ${GMOCK_INCLUDE_DIRS})
target_link_libraries(gmock INTERFACE gtest)

add_library(gmock_main ${findgmock_lib_type} IMPORTED)
set_property(TARGET gmock_main PROPERTY IMPORTED_LOCATION ${findgmock_gmock_main_lib})
target_include_directories(gmock_main INTERFACE ${GMOCK_INCLUDE_DIRS})
target_link_libraries(gmock_main INTERFACE gmock)

set(GTEST_LIBRARIES gtest)
set(GTEST_MAIN_LIBRARIES gtest_main)
set(GMOCK_LIBRARIES gmock_main gmock)
set(GTEST_BOTH_LIBRARIES ${GTEST_LIBRARIES} ${GTEST_MAIN_LIBRARIES})

# Old names
set(GTEST_LIBRARY gtest)
set(GTEST_MAIN_LIBRARY gtest_main)
set(GMOCK_LIBRARY gmock)
set(GMOCK_MAIN_LIBRARY gmock_main)
set(GMOCK_BOTH_LIBRARIES gmock_main gmock)
# This used to be "${GTEST_BOTH_LIBRARIES} ${GMOCK_BOTH_LIBRARIES}", but
# I understand that you're not supposd to include gtest_main and gmock_main
# at the same time.
set(GTEST_ALL_LIBRARIES ${GTEST_LIBRARY} ${GMOCK_BOTH_LIBRARIES})

unset(findgmock_cxx_flags)
unset(findgmock_bin_dir)
unset(findgmock_lib_suffix)
unset(findgmock_lib_type)
unset(findgmock_gtest_lib)
unset(findgmock_gtest_main_lib)
unset(findgmock_gmock_lib)
unset(findgmock_gmock_main_lib)
