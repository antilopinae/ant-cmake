cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)

include(FetchContent)
include(CMakePrintHelpers)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/find")

#[[
# .SYNOPSIS
#   find_or_clone_dependency(<dependency_name> <git_url> <git_tag>
#                            [TRY_FIND_PACKAGE]
#                            [SOURCE_SUBDIR <subdir>]
#                            [FETCHCONTENT_ARGS <args...>]
#                            [CMAKE_ARGS <args...>])
#
# .DESCRIPTION
#   Tries to find a package using find_package(). If not found (or if TRY_FIND_PACKAGE is not specified),
#   it fetches the dependency using FetchContent from the specified Git repository and tag.
#
# .PARAMETER <dependency_name>
#   The logical name of the dependency (e.g., "glfw", "imgui").
#   This name will be used for FetchContent variables and target names.
#
# .PARAMETER <git_url>
#   The URL of the Git repository.
#
# .PARAMETER <git_tag>
#   The Git tag, branch, or commit hash to check out.
#
# .PARAMETER TRY_FIND_PACKAGE
#   If present, the function will first attempt to find the package using `find_package(<dependency_name>)`.
#   If found, FetchContent will not be used.
#
# .PARAMETER SOURCE_SUBDIR <subdir>
#   If the CMakeLists.txt of the dependency is not in the root of its source directory,
#   specify the subdirectory here (e.g., for ImGui if using a fork without top-level CMakeLists.txt).
#   This is passed to FetchContent_Declare's SOURCE_SUBDIR argument.
#
# .PARAMETER FETCHCONTENT_ARGS <args...>
#   Additional arguments to pass directly to FetchContent_Declare (e.g., QUIET, SYSTEM).
#
# .PARAMETER CMAKE_ARGS <args...>
#   CMake arguments to pass to the sub-build of the dependency (e.g., -DBUILD_SHARED_LIBS=OFF).
#   Common options like disabling examples, tests, docs for dependencies are handled by default.
#
# .EXAMPLE
#   find_or_clone_dependency(glfw "https://github.com/glfw/glfw.git" "3.3.8" TRY_FIND_PACKAGE)
#   find_or_clone_dependency(imgui "https://github.com/ocornut/imgui.git" "v1.89.9"
#     CMAKE_ARGS -DIMGUI_BUILD_EXAMPLES=OFF
#   )
#]]
function(find_or_clone_dependency dependency_name git_url git_tag)
    set(options TRY_FIND_PACKAGE)
    set(oneValueArgs SOURCE_SUBDIR EXPECTED_TARGET)
    set(multiValueArgs FETCHCONTENT_ARGS CMAKE_ARGS)
    set(source_dir ${CMAKE_CURRENT_LIST_DIR}/Extern/${dependency_name})
    set(bin_dir ${CMAKE_BINARY_DIR}/Extern-Build/${dependency_name}-build)
    string(TOUPPER ${dependency_name} DEPENDENCY_NAME)
    set(FETCHCONTENT_UPDATES_DISCONNECTED_${DEPENDENCY_NAME} TRUE)

    cmake_parse_arguments(FOC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    string(TOUPPER "${dependency_name}" dep_name_upper)

    if(FOC_TRY_FIND_PACKAGE)
        find_package(${dependency_name} QUIET)
    endif()

    if(TARGET ${dependency_name} OR ${dep_name_upper}_FOUND OR ${dependency_name}_FOUND) # Check for target or _FOUND variable
        message(STATUS "${dependency_name} found or already processed.")
        if(TARGET ${dependency_name})
            cmake_print_properties(TARGETS ${dependency_name} PROPERTIES TYPE ALIASED_TARGET IMPORTED)
        endif()
        return()
    endif()

    message(STATUS "Dependency ${dependency_name} not found via find_package, proceeding with FetchContent from ${git_url} @ ${git_tag}")

    # Default CMake arguments to pass to the dependency's build
    # These are common options to disable for dependencies to speed up builds and reduce clutter.
    list(APPEND common_cmake_args
        # "-D${dep_name_upper}_ENABLE_INSTALL=OFF" # Some projects use this pattern
        "-D${dep_name_upper}_BUILD_EXAMPLES=OFF"
        "-D${dep_name_upper}_BUILD_TESTS=OFF"
        "-D${dep_name_upper}_BUILD_TESTING=OFF"
        "-D${dep_name_upper}_BUILD_DOCS=OFF"
        "-DBUILD_EXAMPLES=OFF"
        "-DBUILD_TESTING=OFF"
        "-DBUILD_TESTS=OFF"
        "-DBUILD_DOCS=OFF"
        "-DENABLE_EXAMPLES=OFF"
        "-DENABLE_TESTS=OFF"
        "-DENABLE_TESTING=OFF"
    )
    if(FOC_CMAKE_ARGS)
        list(APPEND common_cmake_args ${FOC_CMAKE_ARGS})
    endif()
    list(REMOVE_DUPLICATES common_cmake_args) # Ensure clean list

    if(FOC_SOURCE_SUBDIR)
        set(source_subdir_arg SOURCE_SUBDIR ${FOC_SOURCE_SUBDIR})
    endif()

    # Configure FetchContent for this dependency
    # Using a unique prefix for FetchContent variables related to this specific call if needed,
    # FETCHCONTENT_BASE_DIR can be set globally to control where all fetched content goes.
    # Default is ${CMAKE_BINARY_DIR}/_deps
    FetchContent_Declare(${dependency_name}
        GIT_REPOSITORY      ${git_url}
        GIT_TAG             ${git_tag}
        OVERRIDE_FIND_PACKAGE # Allows this to satisfy subsequent find_package calls
        SOURCE_DIR ${source_dir}
        BINARY_DIR ${bin_dir}
        ${source_subdir_arg} # Pass along if provided
        CMAKE_ARGS          ${common_cmake_args}
        ${FOC_FETCHCONTENT_ARGS} # Pass through any other FetchContent_Declare args
        # QUIET             # Suppresses FetchContent download/update messages
        # SYSTEM            # Marks include directories from this dependency as SYSTEM
    )

    if(EXISTS ${source_dir})
        set(FETCHCONTENT_SOURCE_DIR_${DEPENDENCY_NAME} ${source_dir})
    endif()

    # Make the content available (downloads, updates, and configures/builds if necessary)
    # This will also add the targets from the dependency's CMakeLists.txt.
    FetchContent_MakeAvailable(${dependency_name})

    if(FOC_EXPECTED_TARGET)
        if(TARGET ${FOC_EXPECTED_TARGET} AND NOT TARGET ${dependency_name})
            add_library(${dependency_name} ALIAS ${FOC_EXPECTED_TARGET})
        elseif(TARGET ${dependency_name} AND NOT TARGET ${FOC_EXPECTED_TARGET})
            add_library(${FOC_EXPECTED_TARGET} ALIAS ${dependency_name})
        elseif(NOT TARGET ${dependency_name} AND NOT TARGET ${FOC_EXPECTED_TARGET})
            message(WARNING "Neither ${dependency_name} nor ${FOC_EXPECTED_TARGET} found as a target after FetchContent.")
        endif()
    elseif(NOT TARGET ${dependency_name})
        message(WARNING "Target ${dependency_name} not found as a target after FetchContent.")
    endif()

    # After MakeAvailable, the target should exist or _FOUND variable should be set
    if(TARGET ${dependency_name} OR
   (FOC_EXPECTED_TARGET AND TARGET ${FOC_EXPECTED_TARGET}) OR ${dep_name_upper}_FOUND OR ${dependency_name}_FOUND)
        message(STATUS "${dependency_name} successfully fetched and made available.")
        if(TARGET ${dependency_name})
            get_target_property(dep_type ${dependency_name} TYPE)
            get_target_property(dep_src_dir ${dependency_name} SOURCE_DIR) # May not be set for INTERFACE libs
            message(STATUS "  ${dependency_name} target type: ${dep_type}")
            if(dep_src_dir)
                 message(STATUS "  ${dependency_name} source directory (populated by FetchContent): ${dep_src_dir}")
            endif()
        else()
            message(STATUS "  ${dependency_name} processed (likely via find_package due to OVERRIDE_FIND_PACKAGE).")
        endif()
    else()
        message(WARNING "${dependency_name} could not be made available via FetchContent.")
    endif()

endfunction()
