add_library(CompositionStudioEngineBridge SHARED
    CompositionStudioEngineBridge.cpp
    CompositionStudioEngineBridgeV100.cpp
)

target_include_directories(CompositionStudioEngineBridge PRIVATE
    ${CMAKE_SOURCE_DIR}/magda/daw
)

target_link_libraries(CompositionStudioEngineBridge PRIVATE
    magda_daw
)

set_target_properties(CompositionStudioEngineBridge PROPERTIES
    OUTPUT_NAME "CompositionStudioEngineBridge"
    MACOSX_RPATH ON
)
