cmake_minimum_required(VERSION 3.26.0)

include(FetchContent)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Cmake/FindOrCloneDependency.cmake")
    include(FindOrCloneDependency)
    set(CUSTOM_DEP_HANDLER_INCLUDED TRUE)
else()
    message(WARNING "DependencyManagement: cmake/FindOrCloneDependency.cmake not found.")
    set(CUSTOM_DEP_HANDLER_INCLUDED FALSE)
endif()

add_subdirectory(Deps)
