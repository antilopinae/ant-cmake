cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)

enable_testing()

find_package(GTest CONFIG REQUIRED)

#include(FetchContent)
#FetchContent_Declare(
#  googletest
#  GIT_REPOSITORY https://github.com/google/googletest.git
#  GIT_TAG release-1.11.0
#)

# For Windows: Prevent overriding the parent project's
# compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
option(INSTALL_GMOCK "Install GMock" OFF)
option(INSTALL_GTEST "Install GTest" OFF)

#FetchContent_MakeAvailable(googletest)

include(GoogleTest)
include(Coverage)
include(Memcheck)

macro(AddTests target)
  AddCoverage(${target})
  target_link_libraries(${target} PRIVATE gtest_main gmock)
  gtest_discover_tests(${target})
  AddMemcheck(${target})
endmacro()

# CUnit
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/ant-cmake/modules")
find_package(CUnit REQUIRED)
