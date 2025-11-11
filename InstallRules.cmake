function(setup_target_installation_rules TARGET_NAME)
    install(TARGETS ${TARGET_NAME}
        RUNTIME DESTINATION bin COMPONENT Runtime
        LIBRARY DESTINATION bin
    )

    install(DIRECTORY "$<TARGET_FILE_DIR:${TARGET_NAME}>/"
        DESTINATION bin
        COMPONENT RuntimeLibraries
        FILES_MATCHING PATTERN "*.so*"
                        PATTERN "*.dll"
        PATTERN "$<TARGET_FILE_NAME:${TARGET_NAME}>" EXCLUDE
    )
endfunction()

install(DIRECTORY ${CMAKE_SOURCE_DIR}/Assets
        DESTINATION .
)
