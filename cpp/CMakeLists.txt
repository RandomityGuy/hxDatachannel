# CMakeList.txt : Top-level CMake project file, do global configuration
# and include sub-projects here.
#
cmake_minimum_required (VERSION 3.8)

# Enable Hot Reload for MSVC compilers if supported.
if (POLICY CMP0141)
  cmake_policy(SET CMP0141 NEW)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project ("hxLibDatachannel")

# Force /MT instead of /MD for all configs (Debug/Release/etc.)
if (MSVC)
    foreach (flag_var
            CMAKE_C_FLAGS
            CMAKE_C_FLAGS_DEBUG
            CMAKE_C_FLAGS_RELEASE
            CMAKE_C_FLAGS_MINSIZEREL
            CMAKE_C_FLAGS_RELWITHDEBINFO
            CMAKE_CXX_FLAGS
            CMAKE_CXX_FLAGS_DEBUG
            CMAKE_CXX_FLAGS_RELEASE
            CMAKE_CXX_FLAGS_MINSIZEREL
            CMAKE_CXX_FLAGS_RELWITHDEBINFO)
        string(REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
    endforeach()
endif()

# Include sub-projects.
add_subdirectory("libdatachannel")

set (SRC_FILES
	"src/datachannel.c"
)

add_library(hxdatachannel.hdll SHARED ${SRC_FILES})
set_target_properties(hxdatachannel.hdll
    PROPERTIES
    PREFIX ""
    OUTPUT_NAME datachannel
    SUFFIX .hdll
)

set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY true) 
install(
    TARGETS
        hxdatachannel.hdll
)

target_include_directories(hxdatachannel.hdll PRIVATE ${HASHLINK_INCLUDE_DIR})
target_link_directories(hxdatachannel.hdll PRIVATE ${HASHLINK_LIBRARY_DIR})
target_link_libraries(hxdatachannel.hdll libhl datachannel-static)
