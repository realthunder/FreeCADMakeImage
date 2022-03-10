mkdir -p build/release
cd build/release

declare -a CMAKE_PLATFORM_FLAGS

# temporary workaround for vtk-cmake setup
# should be applied @vtk-feedstock
if [[ ${HOST} =~ .*linux.* ]]; then
    # if test -f ${PREFIX}/lib/cmake/vtk-*/Modules/vtkhdf5.cmake; then
    #     LIBPTHREAD=$(find ${PREFIX} -name "libpthread.so") sed -i 's#/home/conda/feedstock_root/build_artifacts/vtk_.*_build_env/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib.*;##g' ${PREFIX}/lib/cmake/vtk-*/Modules/vtkhdf5.cmake
    # fi

    # temporary workaround for qt-cmake:
    sed -i 's|_qt5gui_find_extra_libs(EGL.*)|_qt5gui_find_extra_libs(EGL "EGL" "" "")|g' $PREFIX/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
    sed -i 's|_qt5gui_find_extra_libs(OPENGL.*)|_qt5gui_find_extra_libs(OPENGL "GL" "" "")|g' $PREFIX/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
    cmake_generator="Ninja"
else
    cmake_generator="Unix Makefiles"
    CMAKE_PLATFORM_FLAGS+=(-DFREECAD_USE_3DCONNEXION:BOOL=ON)
    CMAKE_PLATFORM_FLAGS+=(-D3DCONNEXIONCLIENT_FRAMEWORK:FILEPATH="/Library/Frameworks/3DconnexionClient.framework")
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
      -D PYTHON_EXECUTABLE:FILEPATH=$PREFIX/bin/python \
      -D BUILD_FEM_NETGEN:BOOL=ON \
      -D BUILD_PLOT:BOOL=OFF \
      -D BUILD_SHIP:BOOL=OFF \
      -D OCCT_CMAKE_FALLBACK:BOOL=OFF \
      -D FREECAD_USE_QT_DIALOG:BOOL=ON \
      -D Boost_NO_BOOST_CMAKE:BOOL=ON \
      -D FREECAD_USE_QWEBKIT:BOOL=ON \
      -D FREECAD_USE_PCL:BOOL=OFF \
      -D BUILD_DYNAMIC_LINK_PYTHON:BOOL=OFF \
      ${CMAKE_PLATFORM_FLAGS[@]} \
      ../..

if [ "${cmake_generator}" = 'Ninja' ]; then
    ninja install
else
    cmake --build . --target install --parallel 4
fi
rm -r ${PREFIX}/doc     # smaller size of package!
