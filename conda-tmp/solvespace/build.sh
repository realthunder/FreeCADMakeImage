mkdir -p build
cd build

cmake -G "Ninja" \
      -D CMAKE_INSTALL_PREFIX=$PREFIX \
      -D CMAKE_BUILD_TYPE=Release \
      -D BUILD_PYTHON=ON \
      ..

ninja _slvs -v -w dupbuild=warn
cp src/swig/python/_slvs.so src/swig/python/slvs.py $SP_DIR
