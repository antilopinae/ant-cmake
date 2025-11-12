cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)

function(add_c_kernel_module MODULE_NAME MODULE_SRC_DIR)
    set(MODULE_SRC ${ARGN})

    set(MODULE_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME}")
    set(MODULE_OUT "${MODULE_BUILD_DIR}/${MODULE_NAME}.ko")

    message(STATUS "Kernel source/headers dir used: ${KERNEL_HEADERS_DIRECTORY}")
    message(STATUS "Built module output expected at: ${MODULE_OUT}")

    set(MODULE_OBJ_FILES "")

    foreach (SRC_FILE IN LISTS MODULE_SRC)
        get_filename_component(BASE_NAME ${SRC_FILE} NAME_WE)
        list(APPEND MODULE_OBJ_FILES "${BASE_NAME}.o")
    endforeach ()

    add_library(${MODULE_NAME}_obj OBJECT ${MODULE_SRC})

    string(REPLACE ";" " " MODULE_OBJ_FILES_STR "${MODULE_OBJ_FILES}")

    file(WRITE "${MODULE_BUILD_DIR}/Makefile"
            "obj-m := ${MODULE_NAME}.o\n"
            "${MODULE_NAME}-objs := ${MODULE_OBJ_FILES_STR}\n\n"
            "EXTRA_CFLAGS += -I${MODULE_BUILD_DIR}/include\n\n"
    )

    set(C_MODULE_OBJ_FILES "")

    foreach (SRC_FILE IN LISTS MODULE_SRC)
        get_filename_component(FILE_EXT ${SRC_FILE} EXT)
        get_filename_component(BASE_NAME ${SRC_FILE} NAME_WE)

        if ("${FILE_EXT}" STREQUAL ".c")
            list(APPEND C_MODULE_OBJ_FILES "${BASE_NAME}.o")
            file(APPEND "${MODULE_BUILD_DIR}/Makefile"
                    "${BASE_NAME}.o: CFLAGS_${BASE_NAME}.o := \$(EXTRA_CFLAGS)\n\n"
            )
        endif ()
    endforeach ()

    file(APPEND "${MODULE_BUILD_DIR}/Makefile"
            "KDIR := ${KERNEL_HEADERS_DIRECTORY}\n"
            "PWD := \$(shell pwd)\n\n"
            "all:\n"
            "\t\$(MAKE) -C \$(KDIR) M=\$(PWD) modules\n\n"
            "clean:\n"
            "\t\$(MAKE) -C \$(KDIR) M=\$(PWD) clean\n\n"
    )

    add_custom_target(module-${MODULE_NAME}-build
            COMMAND ${CMAKE_COMMAND} -E make_directory ${MODULE_BUILD_DIR}
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${MODULE_SRC} ${MODULE_BUILD_DIR}/
            COMMAND ${CMAKE_COMMAND} -E make_directory ${MODULE_BUILD_DIR}/include/
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${MODULE_SRC_DIR}/include/ ${MODULE_BUILD_DIR}/include/
            COMMAND ${CMAKE_COMMAND} -E chdir ${MODULE_BUILD_DIR} make -f Makefile
            WORKING_DIRECTORY ${MODULE_SRC_DIR}
            BYPRODUCTS ${MODULE_OUT}
    )

    add_dependencies(module-${MODULE_NAME}-build kernel-headers)

    add_custom_target(module-${MODULE_NAME}-install ALL
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/modules
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${MODULE_OUT} ${CMAKE_BINARY_DIR}/modules/
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/modules/include/${MODULE_NAME}
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${MODULE_BUILD_DIR}/include ${CMAKE_BINARY_DIR}/modules/include/${MODULE_NAME}
            DEPENDS module-${MODULE_NAME}-build
            COMMENT "Copying ${MODULE_OUT} to ${CMAKE_BINARY_DIR}/modules/"
    )

    add_custom_target(module-${MODULE_NAME}-clean
            COMMAND ${CMAKE_COMMAND} -E chdir ${MODULE_BUILD_DIR} make -f Makefile clean
    )

    add_custom_target(${MODULE_NAME} ALL
            DEPENDS module-${MODULE_NAME}-install
    )
endfunction()
