cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "vitaltrack_eeg")
project(${PROJECT_NAME} LANGUAGES NONE)

# The prebuilt core, bundled next to the app (lib/ of the bundle).
set(vitaltrack_eeg_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libvitaltrack_core.so"
  PARENT_SCOPE
)
