#################################################################
# HEADER
#################################################################

CMAKE_MINIMUM_REQUIRED(VERSION 2.8.11)
SET(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS TRUE)

PROJECT(FEMPAR_DRIVER Fortran C)

SET(CMAKE_VERBOSE_MAKEFILE TRUE)

#################################################################
# BUILD PATHS
#################################################################

SET(BINARY_OUTPUT_PATH ${PROJECT_BINARY_DIR})
SET(EXECUTABLE_OUTPUT_PATH ${BINARY_OUTPUT_PATH}/bin)
SET(CMAKE_Fortran_MODULE_DIRECTORY ${BINARY_OUTPUT_PATH}/modules)

#################################################################
# CONFIGURATION TYPES & BUILD MODE
#################################################################

SET(CMAKE_CONFIGURATION_TYPES DEBUG RELEASE)
IF(NOT CMAKE_BUILD_TYPE)
  SET(CMAKE_BUILD_TYPE DEBUG CACHE STRING
      "Choose the type of build, options are: NONE DEBUG RELEASE"
      FORCE)

  SET_PROPERTY(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS NONE DEBUG RELEASE)
ENDIF(NOT CMAKE_BUILD_TYPE)

#################################################################
# FFLAGS depend on the compiler and the build type
#################################################################

GET_FILENAME_COMPONENT(Fortran_COMPILER_NAME ${CMAKE_Fortran_COMPILER} NAME)

STRING(TOUPPER "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE_UPPER)
IF(CMAKE_BUILD_TYPE_UPPER STREQUAL "DEBUG")
#   SET(MACROS "${MACROS} -DDEBUG -Dmemcheck")
    ADD_DEFINITIONS(-DDEBUG)
    ADD_DEFINITIONS(-Dmemcheck)
ENDIF()

SET(OPENMP_FLAGS "")
IF(DEFINED ${PROJECT_NAME}_ENABLE_OPENMP AND ${PROJECT_NAME}_ENABLE_OPENMP) 
  FIND_PACKAGE( OpenMP )
  IF(${OPENMP_FOUND})
     SET(OPENMP_FLAGS ${OpenMP_Fortran_FLAGS})
  ENDIF()
ENDIF()

message(STATUS "COMPILER INFO: ${CMAKE_Fortran_COMPILER_ID} - ${Fortran_COMPILER_NAME}")

IF (${CMAKE_Fortran_COMPILER_ID} STREQUAL "GNU" OR Fortran_COMPILER_NAME MATCHES "gfortran*")
  # gfortran 
  set (FORTRAN_EXTRA_FLAGS "-fdefault-real-8 -ffree-line-length-0 -cpp -Wimplicit-interface ${OPENMP_FLAGS}  ${FORTRAN_EXTRA_FLAGS}")
  set (CMAKE_Fortran_FLAGS "${FORTRAN_EXTRA_FLAGS} ${MACROS} ${INCLUDES} " CACHE STRING "" FORCE)
  set (CMAKE_Fortran_FLAGS_DEBUG   "-g -fbacktrace -fbounds-check -Wimplicit-interface " CACHE STRING "" FORCE)
ELSEIF (${CMAKE_Fortran_COMPILER_ID} STREQUAL "Intel" OR Fortran_COMPILER_NAME MATCHES "ifort*")
  # ifort
  set (FORTRAN_EXTRA_FLAGS "-r8 -fpp -W1 -fPIC -assume realloc-lhs ${OPENMP_FLAGS}  ${FORTRAN_EXTRA_FLAGS}")
  set (CMAKE_Fortran_FLAGS "${FORTRAN_EXTRA_FLAGS} ${MACROS} ${INCLUDES}" CACHE STRING "" FORCE)
  set (CMAKE_Fortran_FLAGS_DEBUG   "-O0 -traceback -g -debug all -check all,noarg_temp_created -ftrapuv -warn nointerfaces" CACHE STRING "" FORCE)
# A partir de CMake 3.1
# -prof-gen:srcpos -prof-dir${PROJECT_BINARY_DIR}
ELSEIF (${CMAKE_Fortran_COMPILER_ID} STREQUAL "XL" OR Fortran_COMPILER_NAME MATCHES "xlf*")
  # xlf
  set (FORTRAN_EXTRA_FLAGS "-q64 -qrealsize=8 -qsuffix=f=f90:cpp=f90 ${OPENMP_FLAGS}  ${FORTRAN_EXTRA_FLAGS}")
  set (CMAKE_Fortran_FLAGS "${FORTRAN_EXTRA_FLAGS} ${MACROS} ${INCLUDES}" CACHE STRING "" FORCE)
  set (CMAKE_Fortran_FLAGS_RELEASE "-O3 -qstrict " CACHE STRING "" FORCE)
  set (CMAKE_Fortran_FLAGS_DEBUG   "-O0 -g -qfullpath -qkeepparm " CACHE STRING "" FORCE)
ELSE ()
  message ("No optimized Fortran compiler flags are known, we just try -O2...")
  set (CMAKE_Fortran_FLAGS_RELEASE "-O2")
  set (CMAKE_Fortran_FLAGS_DEBUG   "-O0 -g")
ENDIF ()

SET(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,--allow-multiple-definition")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--allow-multiple-definition")

message (STATUS "CMAKE_Fortran_COMPILER full path: " ${CMAKE_Fortran_COMPILER})
message (STATUS "CMAKE_Fortran_FLAGS: " ${CMAKE_Fortran_FLAGS})
message (STATUS "CMAKE_Fortran_FLAGS_RELEASE: " ${CMAKE_Fortran_FLAGS_RELEASE})
message (STATUS "CMAKE_Fortran_FLAGS_DEBUG: " ${CMAKE_Fortran_FLAGS_DEBUG})

#################################################################
# Find Fempar
#################################################################

IF(${FEMPAR_DIR})
    GET_FILENAME_COMPONENT(FEMPAR_DIR ${FEMPAR_DIR} ABSOLUTE BASE_DIR ${CMAKE_BINARY_DIR})
ENDIF()
FIND_PACKAGE(FEMPAR REQUIRED)
INCLUDE_DIRECTORIES(${FEMPAR_INCLUDES})

#################################################################
# Drivers
#################################################################

# Search all files and directories in the top directory
FILE(GLOB DIRECTORIES * NAME_WE)
FOREACH( DIR ${DIRECTORIES})
    GET_FILENAME_COMPONENT(DRIVER ${DIR} NAME_WE)
    IF(NOT  ${DRIVER} MATCHES "CMakeLists")
        SET(DRIVERS "${DRIVERS} \n    ${DRIVER}")
    ENDIF()
ENDFOREACH()

IF(FEMPAR_DRIVER)

    SET(DRIVERS_PATH ${CMAKE_SOURCE_DIR})
    SET(FEMPAR_DRIVER ${FEMPAR_DRIVER} CACHE STRING "Name of a directory in ${DRIVERS_PATH} containing the driver")

    FILE(GLOB DRIVERS_SRC ${DRIVERS_PATH}/${FEMPAR_DRIVER}/*.f90 ${DRIVERS_PATH}/${FEMPAR_DRIVER}/*.F90)
    SET(DRIVERS_SRC ${DRIVERS_SRC})

    IF(NOT DRIVERS_SRC)
        MESSAGE(FATAL_ERROR "\nFempar Driver '${FEMPAR_DRIVER}' not found! \nList of available Drivers: ${DRIVERS}")
    ENDIF()

    FOREACH(DRIVER_SRC ${DRIVERS_SRC})
        GET_FILENAME_COMPONENT(EXE_NAME ${DRIVER_SRC} NAME_WE)
        UNSET(${EXE_NAME}_MODULES_SRC CACHE)
        SET(${EXE_NAME}_MODULES_DIR ${DRIVERS_PATH}/${FEMPAR_DRIVER}/modules)
        IF(EXISTS "${${EXE_NAME}_MODULES_DIR}" AND IS_DIRECTORY "${${EXE_NAME}_MODULES_DIR}")
            FILE(GLOB ${EXE_NAME}_MODULES_SRC ${${EXE_NAME}_MODULES_DIR}/*.f90 ${${EXE_NAME}_MODULES_DIR}/*.F90)
        ENDIF()
        ADD_EXECUTABLE(${EXE_NAME} ${DRIVER_SRC} ${${EXE_NAME}_MODULES_SRC})
        TARGET_LINK_LIBRARIES(${EXE_NAME} ${FEMPAR_LIBS})
    ENDFOREACH()

ELSE()
    MESSAGE(FATAL_ERROR "\nFempar Driver name must be passed to cmake with '-DFEMPAR_DRIVER=fempar_driver_name'. \nList of available Drivers: ${DRIVERS}")
ENDIF()



