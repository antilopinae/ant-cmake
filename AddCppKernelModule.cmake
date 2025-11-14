cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)

# To build kernel module with cpp, I used this article:
# https://olegkutkov.me/2019/11/10/cpp-in-linux-kernel/
# In common generated Makefile script will be as this:
#[[

MOD_NAME    := cpp_kernel
KERNEL      := /lib/modules/$(shell uname -r)/build
FLAGS       := -Wall
KMOD_DIR    := $(shell pwd)

OBJECTS := module.o \
kern_lib.o \
logger.o \
cpp_support.cpp.o \
cpp_module.cpp.o

ccflags-y += $(FLAGS)

# Apply C flags to the cpp compiler and disable cpp features that can't be supported in the kernel module
cxx-selected-flags = $(shell echo $(KBUILD_CFLAGS) \
            | sed s/-D\"KBUILD.\"//g \
            | sed s/-Werror=strict-prototypes//g \
            | sed s/-Werror=implicit-function-declaration//g \
            | sed s/-Werror=implicit-int//g \
            | sed s/-Wdeclaration-after-statement//g \
            | sed s/-Wno-pointer-sign//g \
            | sed s/-Werror=incompatible-pointer-types//g \
            | sed s/-Werror=designated-init//g \
            | sed s/-std=gnu90//g )

cxxflags = $(FLAGS) \
$(cxx-selected-flags) \
-fno-builtin \
-nostdlib \
-fno-rtti \
-fno-exceptions \
-std=c++0x


obj-m += $(MOD_NAME).o

$(MOD_NAME)-y := $(OBJECTS)

.PHONY: $(MOD_NAME).ko
$(MOD_NAME).ko:
@echo building module
make -C $(KERNEL) M=$(KMOD_DIR) modules

cxx-prefix := " $(HOSTCXX) [M]  "

%.cpp.o: %.cpp
@echo $(cxx-prefix)$@
@$(HOSTCXX) $(cxxflags) -c $< -o $@
@echo -n > $$(dirname $@)/.$$(basename $@).cmd

.PHONY: clean
clean:
@echo clean
make -C $(KERNEL) M=$(KMOD_DIR) clean

#]]

# This function generates Makefile and builds modules,
# kernel cpp-module will be available in CMAKE_BINARY_DIR/modules
# with its headers in CMAKE_BINARY_DIR/modules/include/MODULE_NAME
function(add_cpp_kernel_module)
    set(options "")
    set(oneValueArgs MODULE_NAME MODULE_SRC_DIR)
    set(multiValueArgs MODULE_SRC MODULE_INCLUDE_DIRS)

    cmake_parse_arguments(PARAM
            "${options}"
            "${oneValueArgs}"
            "${multiValueArgs}"
            ${ARGN}
    )

    set(MODULE_NAME ${PARAM_MODULE_NAME})
    set(MODULE_SRC ${PARAM_MODULE_SRC})
    set(MODULE_SRC_DIR ${PARAM_MODULE_SRC_DIR})
    set(MODULE_INCLUDE_DIRS ${PARAM_MODULE_INCLUDE_DIRS})

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
        elseif ("${FILE_EXT}" STREQUAL ".c")
            list(APPEND MODULE_OBJ_FILES "${BASE_NAME}.o")
        endif ()
    endforeach ()

    string(REPLACE ";" " " MODULE_OBJ_FILES_STR "${MODULE_OBJ_FILES}")

    file(WRITE "${MODULE_BUILD_DIR}/Makefile"
            "MOD_NAME := ${MODULE_NAME}\n"
            "KERNEL := ${KERNEL_HEADERS_DIRECTORY}\n"
            "FLAGS := -Wall\n"
    )

    foreach (DIR ${MODULE_INCLUDE_DIRS})
        list(APPEND COMMANDS_COPY_INCLUDE_DIRECTORIES
                COMMAND ${CMAKE_COMMAND} -E make_directory ${MODULE_BUILD_DIR}/${DIR}
                COMMAND ${CMAKE_COMMAND} -E copy_directory ${MODULE_SRC_DIR}/${DIR} ${MODULE_BUILD_DIR}/${DIR}
        )

        # Include directories
        file(APPEND "${MODULE_BUILD_DIR}/Makefile"
                "FLAGS += -I${MODULE_BUILD_DIR}/${DIR}\n"
                #                "EXTRA_CXXFLAGS += -I${MODULE_BUILD_DIR}/${DIR}\n\n"
        )
    endforeach ()

    file(APPEND "${MODULE_BUILD_DIR}/Makefile"
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

    include_directories(${MODULE_SRC_DIR}/include/)

    # include kernel headers dir to syntax highlighting
    include_directories(${KERNEL_HEADERS_DIRECTORY}/include/)

    add_custom_target(module-${MODULE_NAME}-build
            COMMAND ${CMAKE_COMMAND} -E make_directory ${MODULE_BUILD_DIR}
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${MODULE_SRC} ${MODULE_BUILD_DIR}/
            ${COMMANDS_COPY_INCLUDE_DIRECTORIES}
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