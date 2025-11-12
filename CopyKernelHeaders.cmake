cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)

execute_process(COMMAND uname -r
        OUTPUT_VARIABLE ANT_UNAME_R
        OUTPUT_STRIP_TRAILING_WHITESPACE)

message(STATUS "Detected kernel release: ${ANT_UNAME_R}")

set(KERNEL_BUILD_DIRECTORY "" CACHE INTERNAL "Path to kernel src")

set(LOCAL_KERNEL_BUILD_DIR "/lib/modules/${ANT_UNAME_R}/build")
set(USE_LOCAL_KERNEL_BUILD_DIR FALSE)

if (EXISTS "${LOCAL_KERNEL_BUILD_DIR}")
    message(STATUS "Found kernel build dir: ${LOCAL_KERNEL_BUILD_DIR} — will use system headers")
    set(USE_LOCAL_KERNEL_BUILD_DIR TRUE)
endif ()

if (NOT USE_LOCAL_KERNEL_BUILD_DIR)
    message(FATAL_ERROR "Not found kernel build dir")

    string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ MATCHED ${ANT_UNAME_R})
    if (MATCHED)
        set(ANT_KERNEL_VERSION ${CMAKE_MATCH_1})
        message(STATUS "Extracted semantic kernel version: ${ANT_KERNEL_VERSION}")
    else ()
        message(FATAL_ERROR "Cannot extract semantic X.Y.Z from ${ANT_UNAME_R}; set kernel version manually")
    endif ()

    set(ANT_KERNEL_TARBALL "linux-${ANT_KERNEL_VERSION}.tar.xz")
    set(ANT_KERNEL_URL "https://cdn.kernel.org/pub/linux/kernel/v6.x/${ANT_KERNEL_TARBALL}")

    ExternalProject_Add(kernel-download-src
            URL ${ANT_KERNEL_URL}
            PREFIX ${CMAKE_BINARY_DIR}/kernel-src
            CONFIGURE_COMMAND ""
            BUILD_COMMAND make -C <SOURCE_DIR> defconfig && make -C <SOURCE_DIR> vmlinux -j${CMAKE_BUILD_PARALLEL_LEVEL}
            BUILD_BYPRODUCTS <SOURCE_DIR>/vmlinux
            INSTALL_COMMAND ""
    )

    ExternalProject_Get_Property(kernel-download-src SOURCE_DIR)
    set(KERNEL_BUILD_DIRECTORY ${SOURCE_DIR} CACHE INTERNAL "Path to kernel build src")

    add_custom_target(get-headers ALL
            DEPENDS ${SOURCE_DIR}/vmlinux
            COMMENT "Kernel vmlinux will be available at: ${SOURCE_DIR}"
    )

    add_dependencies(get-headers kernel-download-headers)
else ()
    set(KERNEL_BUILD_DIRECTORY ${LOCAL_KERNEL_BUILD_DIR} CACHE INTERNAL "Path to kernel build src")
    add_custom_target(get-headers ALL
            COMMENT "Using system kernel headers at ${KERNEL_BUILD_DIRECTORY}"
    )
endif ()

if (NOT EXISTS "${KERNEL_BUILD_DIRECTORY}/Makefile")
    message(FATAL_ERROR "Kernel build dir ${KERNEL_BUILD_DIRECTORY} has no Makefile. Install linux-headers for your kernel.")
endif ()

set(KERNEL_HEADERS_DIRECTORY "${CMAKE_BINARY_DIR}/kernel-headers" CACHE INTERNAL "Path to kernel headers")

add_custom_target(kernel-headers ALL
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${KERNEL_BUILD_DIRECTORY} ${KERNEL_HEADERS_DIRECTORY}
        COMMENT "Copying kernel headers in ${KERNEL_HEADERS_DIRECTORY}"
)

add_dependencies(kernel-headers get-headers)
