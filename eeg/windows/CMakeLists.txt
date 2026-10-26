cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "vitaltrack_eeg")
project(${PROJECT_NAME} LANGUAGES NONE)

# The prebuilt core, copied next to the app's executable.
set(vitaltrack_eeg_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/vitaltrack_core.dll"
  PARENT_SCOPE
)
