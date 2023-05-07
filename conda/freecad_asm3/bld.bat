@echo on

if "%GIT_DESCRIBE_TAG:~-6%"=="stable" (
    set ICON=icon.ico
) else (
    set ICON=icon-daily.ico
)

if exist "%RECIPE_DIR%\extra\%ICON%" (copy /y "%RECIPE_DIR%\extra\%ICON%" src\Main\icon.ico)

mkdir build
cd build

set "CFLAGS= "
set "CXXFLAGS= "
set "LDFLAGS_SHARED= ucrt.lib"

REM remove Chocolatey/bin from search path to hide ccache, as it cause resouce compilation failure
set PATH=%PATH:C:\ProgramData\Chocolatey\bin;=%
echo "modified path: %PATH%"

cmake -G "Ninja" ^
      -D BUID_WITH_CONDA:BOOL=ON ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D FREECAD_LIBPACK_USE:BOOL=OFF ^
      -D CMAKE_INSTALL_PREFIX:FILEPATH=%LIBRARY_PREFIX% ^
      -D CMAKE_PREFIX_PATH:FILEPATH=%LIBRARY_PREFIX% ^
      -D CMAKE_INCLUDE_PATH:FILEPATH=%LIBRARY_PREFIX%/include ^
      -D CMAKE_LIBRARY_PATH:FILEPATH=%LIBRARY_PREFIX%/lib ^
      -D CMAKE_INSTALL_LIBDIR:FILEPATH=%LIBRARY_PREFIX%/lib ^
      -D BUILD_QT5:BOOL=ON ^
      -D BUILD_FEM_NETGEN:BOOL=ON ^
      -D OCC_INCLUDE_DIR:FILEPATH=%LIBRARY_PREFIX%/include/opencascade ^
      -D OCC_LIBRARY_DIR:FILEPATH=%LIBRARY_PREFIX%/lib ^
      -D OCC_LIBRARIES:FILEPATH=%LIBRARY_PREFIX%/lib ^
      -D FREECAD_USE_OCC_VARIANT="Official Version" ^
      -D OCC_OCAF_LIBRARIES:FILEPATH=%LIBRARY_PREFIX%/lib ^
      -D BUILD_REVERSEENGINEERING:BOOL=ON ^
      -D Python3_FIND_STRATEGY=LOCATION ^
      -D PYTHON_EXECUTABLE:FILEPATH=%PREFIX%/python ^
      -D Python3_EXECUTABLE:FILEPATH=%PREFIX%/python ^
      -D USE_BOOST_PYTHON:BOOL=OFF ^
      -D FREECAD_USE_PYBIND11:BOOL=ON ^
      -D SMESH_INCLUDE_DIR:FILEPATH=%LIBRARY_PREFIX%/include/smesh ^
      -D SMESH_LIBRARY:FILEPATH="%LIBRARY_PREFIX%/lib/SMESH.lib" ^
      -D FREECAD_USE_EXTERNAL_SMESH:BOOL=ON ^
      -D BUILD_FLAT_MESH:BOOL=ON ^
      -D BUILD_SHIP:BOOL=OFF ^
      -D OCCT_CMAKE_FALLBACK:BOOL=ON ^
      -D BUILD_DYNAMIC_LINK_PYTHON:BOOL=ON ^
      -D Boost_NO_BOOST_CMAKE:BOOL=ON ^
      -D FREECAD_USE_PCH:BOOL=OFF ^
      -D FREECAD_USE_PCL:BOOL=ON ^
      -D INSTALL_TO_SITEPACKAGES:BOOL=ON ^
      -D LZMA_LIBRARY="%LIBRARY_PREFIX%/lib/liblzma.lib" ^
      -D BUILD_TEST:BOOL=OFF ^
      ..

if errorlevel 1 exit 1
ninja install
if errorlevel 1 exit 1

rmdir /s /q "%LIBRARY_PREFIX%\doc"
REM  ren %LIBRARY_PREFIX%\bin\FreeCAD.exe freecad.exe
REM  ren %LIBRARY_PREFIX%\bin\FreeCADCmd.exe freecadcmd.exe
