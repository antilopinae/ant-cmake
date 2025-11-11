macro(Optimized target)
    if(CMAKE_BUILD_TYPE STREQUAL Release)
        target_compile_options(${target}
            PUBLIC -O3
            PUBLIC -finline-functions
            PUBLIC -ftree-vectorize
        )

        include(CheckIPOSupported)
        check_ipo_supported(RESULT ipo_supported)
        if(ipo_supported)
            set(CMAKE_INTERPROCEDURAL_OPTIMIZATION True)
        endif()

    endif()
endmacro()
