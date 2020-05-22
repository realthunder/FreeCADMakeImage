cd superglue
mkdir build
cd build


cmake -G "Ninja" ^
      -D CMAKE_BUILD_TYPE:STRING="Release" ^
      -D CMAKE_PREFIX_PATH:FILEPATH="%LIBRARY_PREFIX%" ^
      -D CMAKE_INSTALL_PREFIX:FILEPATH="%LIBRARY_PREFIX%" ^
      -D CMAKE_INSTALL_LIBDIR:FILEPATH="%LIBRARY_PREFIX%\lib" ^
      ..

if errorlevel 1 exit 1
ninja install
if errorlevel 1 exit 1

cd ..
cd ..

mkdir build
cd build

cmake -G "Ninja" ^
      -D CMAKE_BUILD_TYPE:STRING="Release" ^
      -D CMAKE_PREFIX_PATH:FILEPATH="%LIBRARY_PREFIX%" ^
      -D CMAKE_INSTALL_PREFIX:FILEPATH="%LIBRARY_PREFIX%" ^
      -D SIMAGE_RUNTIME_LINKING:BOOL=ON ^
      -D USE_EXTERNAL_EXPAT:BOOL=ON ^
      -D COIN_BUILD_DOCUMENTATION:BOOL=OFF ^
      -D COIN_BUILD_TESTS:BOOL=OFF ^
      -D COIN_BUILD_DOCUMENTATION:BOOL=OFF ^
      -D USE_SUPERGLU:BOOL=ON ^
      ..

if errorlevel 1 exit 1
ninja install
if errorlevel 1 exit 1
