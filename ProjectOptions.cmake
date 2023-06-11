include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Cmake_Template_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Cmake_Template_setup_options)
  option(Cmake_Template_ENABLE_HARDENING "Enable hardening" ON)
  option(Cmake_Template_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Cmake_Template_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Cmake_Template_ENABLE_HARDENING
    OFF)

  Cmake_Template_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Cmake_Template_PACKAGING_MAINTAINER_MODE)
    option(Cmake_Template_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Cmake_Template_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Cmake_Template_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Cmake_Template_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Cmake_Template_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Cmake_Template_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Cmake_Template_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Cmake_Template_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Cmake_Template_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Cmake_Template_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Cmake_Template_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Cmake_Template_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Cmake_Template_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Cmake_Template_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Cmake_Template_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Cmake_Template_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Cmake_Template_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Cmake_Template_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Cmake_Template_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Cmake_Template_ENABLE_IPO
      Cmake_Template_WARNINGS_AS_ERRORS
      Cmake_Template_ENABLE_USER_LINKER
      Cmake_Template_ENABLE_SANITIZER_ADDRESS
      Cmake_Template_ENABLE_SANITIZER_LEAK
      Cmake_Template_ENABLE_SANITIZER_UNDEFINED
      Cmake_Template_ENABLE_SANITIZER_THREAD
      Cmake_Template_ENABLE_SANITIZER_MEMORY
      Cmake_Template_ENABLE_UNITY_BUILD
      Cmake_Template_ENABLE_CLANG_TIDY
      Cmake_Template_ENABLE_CPPCHECK
      Cmake_Template_ENABLE_COVERAGE
      Cmake_Template_ENABLE_PCH
      Cmake_Template_ENABLE_CACHE)
  endif()

  Cmake_Template_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Cmake_Template_ENABLE_SANITIZER_ADDRESS OR Cmake_Template_ENABLE_SANITIZER_THREAD OR Cmake_Template_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Cmake_Template_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Cmake_Template_global_options)
  if(Cmake_Template_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Cmake_Template_enable_ipo()
  endif()

  Cmake_Template_supports_sanitizers()

  if(Cmake_Template_ENABLE_HARDENING AND Cmake_Template_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Cmake_Template_ENABLE_SANITIZER_UNDEFINED
       OR Cmake_Template_ENABLE_SANITIZER_ADDRESS
       OR Cmake_Template_ENABLE_SANITIZER_THREAD
       OR Cmake_Template_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Cmake_Template_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Cmake_Template_ENABLE_SANITIZER_UNDEFINED}")
    Cmake_Template_enable_hardening(Cmake_Template_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Cmake_Template_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Cmake_Template_warnings INTERFACE)
  add_library(Cmake_Template_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Cmake_Template_set_project_warnings(
    Cmake_Template_warnings
    ${Cmake_Template_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Cmake_Template_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Cmake_Template_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Cmake_Template_enable_sanitizers(
    Cmake_Template_options
    ${Cmake_Template_ENABLE_SANITIZER_ADDRESS}
    ${Cmake_Template_ENABLE_SANITIZER_LEAK}
    ${Cmake_Template_ENABLE_SANITIZER_UNDEFINED}
    ${Cmake_Template_ENABLE_SANITIZER_THREAD}
    ${Cmake_Template_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Cmake_Template_options PROPERTIES UNITY_BUILD ${Cmake_Template_ENABLE_UNITY_BUILD})

  if(Cmake_Template_ENABLE_PCH)
    target_precompile_headers(
      Cmake_Template_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Cmake_Template_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Cmake_Template_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Cmake_Template_ENABLE_CLANG_TIDY)
    Cmake_Template_enable_clang_tidy(Cmake_Template_options ${Cmake_Template_WARNINGS_AS_ERRORS})
  endif()

  if(Cmake_Template_ENABLE_CPPCHECK)
    Cmake_Template_enable_cppcheck(${Cmake_Template_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Cmake_Template_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Cmake_Template_enable_coverage(Cmake_Template_options)
  endif()

  if(Cmake_Template_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Cmake_Template_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Cmake_Template_ENABLE_HARDENING AND NOT Cmake_Template_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Cmake_Template_ENABLE_SANITIZER_UNDEFINED
       OR Cmake_Template_ENABLE_SANITIZER_ADDRESS
       OR Cmake_Template_ENABLE_SANITIZER_THREAD
       OR Cmake_Template_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Cmake_Template_enable_hardening(Cmake_Template_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
