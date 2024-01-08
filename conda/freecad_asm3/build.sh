mkdir -p build/release
cd build/release

declare -a CMAKE_PLATFORM_FLAGS
cmake_generator="Ninja"

# temporary workaround for vtk-cmake setup
# should be applied @vtk-feedstock
if [[ ${HOST} =~ .*linux.* ]]; then
    # if test -f ${PREFIX}/lib/cmake/vtk-*/Modules/vtkhdf5.cmake; then
    #     LIBPTHREAD=$(find ${PREFIX} -name "libpthread.so") sed -i 's#/home/conda/feedstock_root/build_artifacts/vtk_.*_build_env/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib.*;##g' ${PREFIX}/lib/cmake/vtk-*/Modules/vtkhdf5.cmake
    # fi

    # temporary workaround for qt-cmake:
    sed -i 's|_qt5gui_find_extra_libs(EGL.*)|_qt5gui_find_extra_libs(EGL "EGL" "" "")|g' $PREFIX/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
    sed -i 's|_qt5gui_find_extra_libs(OPENGL.*)|_qt5gui_find_extra_libs(OPENGL "GL" "" "")|g' $PREFIX/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
    if test ${CONDA_BUILD_CROSS_COMPILATION}; then
        CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
    fi
fi

if [[ ${HOST} =~ .*darwin.* ]] && [[ ${target_platform} =~ osx-64 ]]; then
    # add hacks for osx here!
    echo "adding hacks for osx"
    
    # should be applied @vtk-feedstock
    # sed -i '381,383d' ${PREFIX}/lib/cmake/vtk-9.0/VTK-targets.cmake

    ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.12.sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk
    ln -s /Applications/Xcode.app /Applications/Xcode_11.7.app

    # install space-mouse
    curl -o /tmp/3dFW.dmg -L 'https://download.3dconnexion.com/drivers/mac/10-6-6_360DF97D-ED08-4ccf-A55E-0BF905E58476/3DxWareMac_v10-6-6_r3234.dmg'
    hdiutil attach -readonly /tmp/3dFW.dmg
    sudo installer -package /Volumes/3Dconnexion\ Software/Install\ 3Dconnexion\ software.pkg -target /
    diskutil eject /Volumes/3Dconnexion\ Software

    # cmake_generator="Unix Makefiles"
    CMAKE_PLATFORM_FLAGS+=(-DFREECAD_USE_3DCONNEXION:BOOL=ON)
    CMAKE_PLATFORM_FLAGS+=(-D3DCONNEXIONCLIENT_FRAMEWORK:FILEPATH="/Library/Frameworks/3DconnexionClient.framework")

fi

if [[ ${HOST} =~ .*darwin.* ]]; then
    CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY -DBOOST_NO_CXX98_FUNCTION_BASE"
fi

cmake -G "$cmake_generator" \
      -D BUID_WITH_CONDA:BOOL=ON \
      -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX:FILEPATH=$PREFIX \
      -D CMAKE_PREFIX_PATH:FILEPATH=$PREFIX \
      -D CMAKE_LIBRARY_PATH:FILEPATH=$PREFIX/lib \
      -D CMAKE_INCLUDE_PATH:FILEPATH=$PREFIX/include \
      -D BUILD_QT5:BOOL=ON \
      -D FREECAD_USE_OCC_VARIANT="Official Version" \
      -D OCC_INCLUDE_DIR:FILEPATH=$PREFIX/include \
      -D USE_BOOST_PYTHON:BOOL=OFF \
      -D FREECAD_USE_PYBIND11:BOOL=ON \
      -D BUILD_ENABLE_CXX_STD:STRING=C++17 \
      -D SMESH_INCLUDE_DIR:FILEPATH=$PREFIX/include/smesh \
      -D FREECAD_USE_EXTERNAL_SMESH=ON \
      -D BUILD_FLAT_MESH:BOOL=ON \
      -D BUILD_WITH_CONDA:BOOL=ON \
      -D Python3_FIND_STRATEGY=LOCATION \
      -D PYTHON_EXECUTABLE:FILEPATH=$PREFIX/bin/python \
      -D Python3_EXECUTABLE:FILEPATH=$PREFIX/bin/python \
      -D Python3_FIND_FRAMEWORK:STRING=NEVER \
      -D BUILD_FEM_NETGEN:BOOL=ON \
      -D BUILD_SHIP:BOOL=OFF \
      -D OCCT_CMAKE_FALLBACK:BOOL=OFF \
      -D FREECAD_USE_QT_DIALOG:BOOL=ON \
      -D Boost_NO_BOOST_CMAKE:BOOL=ON \
      -D FREECAD_USE_QWEBKIT:BOOL=ON \
      -D FREECAD_USE_PCL:BOOL=ON \
      -D BUILD_DYNAMIC_LINK_PYTHON:BOOL=OFF \
      ${CMAKE_PLATFORM_FLAGS[@]} \
      ../..

if [ "${cmake_generator}" = 'Ninja' ]; then
    ninja install
else
    cmake --build . --target install --parallel 4
fi
rm -r ${PREFIX}/doc     # smaller size of package!
