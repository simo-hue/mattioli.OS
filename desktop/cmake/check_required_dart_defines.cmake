function(evolve_check_required_dart_defines flutter_tool_environment)
  set(required_defines
    EVOLVE_SUPABASE_URL
    EVOLVE_SUPABASE_PUBLISHABLE_KEY
  )
  set(missing_defines "")
  set(dart_defines "")

  foreach(env_entry IN LISTS flutter_tool_environment)
    if(env_entry MATCHES "^DART_DEFINES=(.*)$")
      set(dart_defines "${CMAKE_MATCH_1}")
    endif()
  endforeach()

  string(REPLACE "," ";" encoded_defines "${dart_defines}")
  foreach(encoded_define IN LISTS encoded_defines)
    if(NOT encoded_define STREQUAL "")
      string(BASE64_DECODE "${encoded_define}" decoded_define)
      if(decoded_define MATCHES "^([^=]+)=(.*)$")
        set("defined_${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}")
      endif()
    endif()
  endforeach()

  foreach(required_define IN LISTS required_defines)
    if(NOT DEFINED "defined_${required_define}" OR
        "${defined_${required_define}}" STREQUAL "")
      list(APPEND missing_defines "${required_define}")
    endif()
  endforeach()

  if(missing_defines)
    string(REPLACE ";" " " missing_summary "${missing_defines}")
    message(FATAL_ERROR
      "Missing required Flutter dart define(s): ${missing_summary}. "
      "Build desktop with --dart-define-from-file=.env or explicit "
      "--dart-define values."
    )
  endif()
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
  evolve_check_required_dart_defines("${FLUTTER_TOOL_ENVIRONMENT}")
endif()
