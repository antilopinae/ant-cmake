cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)

function(add_cpp_kernel_module MODULE_NAME MODULE_SRC_DIR)
    set(MODULE_SRC ${ARGN})

    set(MODULE_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME}")
    set(MODULE_OUT "${MODULE_BUILD_DIR}/${MODULE_NAME}.ko")

    message(STATUS "Kernel source/headers dir used: ${KERNEL_HEADERS_DIRECTORY}")
    message(STATUS "Built module output expected at: ${MODULE_OUT}")

    set(MODULE_OBJ_FILES "")

    foreach (SRC_FILE IN LISTS MODULE_SRC)
        get_filename_component(FILE_EXT ${SRC_FILE} EXT)
        get_filename_component(BASE_NAME ${SRC_FILE} NAME_WE)
        if ("${FILE_EXT}" STREQUAL ".cpp")
            list(APPEND MODULE_OBJ_FILES "${BASE_NAME}.cpp.o")
        else ()
            list(APPEND MODULE_OBJ_FILES "${BASE_NAME}.o")
        endif ()
    endforeach ()

    string(REPLACE ";" " " MODULE_OBJ_FILES_STR "${MODULE_OBJ_FILES}")

    file(WRITE "${MODULE_BUILD_DIR}/Makefile"
            "MOD_NAME := ${MODULE_NAME}\n"
            "KERNEL := ${KERNEL_HEADERS_DIRECTORY}\n"
            "FLAGS := -Wall\n"
            "EXTRA_CFLAGS += -I${MODULE_BUILD_DIR}/include\n"
            "KMOD_DIR := ${MODULE_BUILD_DIR}\n\n"
            "OBJECTS := ${MODULE_OBJ_FILES_STR}\n\n"
            "ccflags-y += $(FLAGS)\n\n"
            "cxx-selected-flags = $(shell echo $(KBUILD_CFLAGS) \\\n"
            "\t| sed s/-D\\\"KBUILD.\\\"//g \\\n"
            "\t| sed s/-Werror=strict-prototypes//g \\\n"
            "\t| sed s/-Werror=implicit-function-declaration//g \\\n"
            "\t| sed s/-Werror=implicit-int//g \\\n"
            "\t| sed s/-Wdeclaration-after-statement//g \\\n"
            "\t| sed s/-Wno-pointer-sign//g \\\n"
            "\t| sed s/-Werror=incompatible-pointer-types//g \\\n"
            "\t| sed s/-Werror=designated-init//g \\\n"
            "\t| sed s/-std=gnu90//g )\n\n"
            "cxxflags = $(FLAGS) $(cxx-selected-flags) -fno-builtin -nostdlib -fno-rtti -fno-exceptions -std=c++0x\n\n"
            "obj-m += $(MOD_NAME).o\n\n"
            "$(MOD_NAME)-y := $(OBJECTS)\n\n"
            ".PHONY: $(MOD_NAME).ko\n"
            "$(MOD_NAME).ko:\n"
            "\t@echo building module\n"
            "\tmake -C $(KERNEL) M=$(KMOD_DIR) modules\n\n"
            "cxx-prefix := \" $(HOSTCXX) [M]  \"\n\n"
            "%.cpp.o: %.cpp\n"
            "\t@echo $(cxx-prefix)$@\n"
            "\t@$(HOSTCXX) $(cxxflags) -c $< -o $@\n"
            "\t@echo -n > $$(dirname $@)/.$$(basename $@).cmd\n\n"
            ".PHONY: clean\n"
            "clean:\n"
            "\t@echo clean\n"
            "\tmake -C $(KERNEL) M=$(KMOD_DIR) clean\n"
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
