#!/bin/bash

set -e

working_directory=$PWD

output_dir=$working_directory
blazingsql_project_dir=$working_directory/..

if [ ! -z $1 ]; then
  output_dir=$1
fi

# Expand args to absolute/full paths (if the user pass relative paths as args)
output_dir=$(readlink -f $output_dir)
blazingsql_project_dir=$(readlink -f $blazingsql_project_dir)

# NOTE tmp_dir is the prefix (bin, lib, include, build)
#tmp_dir=$working_directory/tmp
# TODO mario
tmp_dir=/opt/blazingsql-powerpc-prefix

build_dir=$tmp_dir/build
blazingsql_build_dir=$build_dir/blazingsql

# Clean the build before start a new one
# TODO percy re-enable this later
#rm -rf $tmp_dir
#mkdir -p $blazingsql_build_dir

MAKEJ=$(nproc)
MAKEJ_CUDF=$(( `nproc` / 2 ))
echo "### Vars ###"
echo "MAKEJ="$MAKEJ
echo "MAKEJ_CUDF="$MAKEJ_CUDF
echo "PATH="$PATH
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/app/tmp/:/app/tmp/include/:/app/tmp/lib
echo "LD_LIBRARY_PATH="$LD_LIBRARY_PATH
#C_INCLUDE_PATH=/app/tmp/include/
#CPLUS_INCLUDE_PATH=/app/tmp/include/
echo "CPLUS_INCLUDE_PATH="$CPLUS_INCLUDE_PATH

echo "output_dir="$output_dir
echo "blazingsql_project_dir="$blazingsql_project_dir
echo "tmp_dir="$tmp_dir
echo "build_dir="$build_dir
echo "blazingsql_build_dir="$blazingsql_build_dir

#BEGIN boost

boost_install_dir=$tmp_dir
boost_build_dir=$build_dir/boost/
echo "boost_install_dir: "$boost_install_dir
echo "boost_build_dir: "$boost_build_dir

# TODO percy mario manage version labels (1.66.0 and 1_66_0)
if [ ! -f $boost_install_dir/include/boost/version.hpp ]; then
    echo "### Boost - start ###"
    mkdir -p $boost_build_dir
    cd $boost_build_dir

    # TODO percy mario manbage boost version
    if [ ! -f $boost_build_dir/boost_1_66_0.tar.gz ]; then
        wget -q https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.gz
    fi

    if [ ! -d $boost_build_dir/boost_1_66_0 ]; then
        echo "Decompressing boost_1_66_0.tar.gz ..."
        tar xf boost_1_66_0.tar.gz
        echo "Boost package boost_1_66_0.tar.gz was decompressed at $boost_dir"
    fi

    # NOTE build Boost with old C++ ABI _GLIBCXX_USE_CXX11_ABI=0 and with -fPIC
    cd boost_1_66_0
    ./bootstrap.sh --with-libraries=system,filesystem,regex,atomic,chrono,container,context,thread --with-icu --prefix=$boost_install_dir
    ./b2 install variant=release define=_GLIBCXX_USE_CXX11_ABI=0 stage threading=multi --exec-prefix=$boost_install_dir --prefix=$boost_install_dir -a
    if [ $? != 0 ]; then
      echo "Error during b2 install"
      exit 1
    fi
    echo "### Boost - end ###"
fi
#END boost

#BEGIN thrift
thrift_install_dir=$tmp_dir
thrift_build_dir=$build_dir/thrift/
echo "thrift_install_dir: "$thrift_install_dir
echo "thrift_build_dir: "$thrift_build_dir

if [ ! -d $thrift_build_dir ]; then
    echo "### Thrift - start ###"
    mkdir -p $thrift_build_dir
    cd $thrift_build_dir

    git clone https://github.com/apache/thrift.git
    cd thrift/
    git checkout 0.13.0

    echo "### Thrift - cmake ###"
    export PY_PREFIX=$thrift_install_dir
    #./bootstrap.sh
    #./configure --prefix=$thrift_install_dir --enable-libs --with-cpp=yes --with-haskell=no --with-nodejs=no --with-nodets=no
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=$thrift_install_dir \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_SHARED_LIBS=ON \
          -DBUILD_TESTING=OFF \
          -DBUILD_EXAMPLES=OFF \
          -DBUILD_TUTORIALS=OFF \
          -DWITH_QT4=OFF \
          -DWITH_C_GLIB=OFF \
          -DWITH_JAVA=OFF \
          -DWITH_PYTHON=OFF \
          -DWITH_HASKELL=OFF \
          -DWITH_CPP=ON \
          -DWITH_STATIC_LIB=OFF \
          -DWITH_LIBEVENT=OFF \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DCMAKE_C_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_CXX_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DBOOST_ROOT=$boost_install_dir \
          .
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Thrift - make install ###"
    make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Thrift - end ###"
fi

#END thrift

#BEGIN flatbuffers
flatbuffers_install_dir=$tmp_dir
flatbuffers_build_dir=$build_dir/flatbuffers
if [ ! -d $flatbuffers_build_dir ]; then
    echo "### Flatbufferts - Start ###"
    mkdir -p $flatbuffers_build_dir
    cd $flatbuffers_build_dir

    git clone https://github.com/google/flatbuffers.git
    cd flatbuffers/
    git checkout 02a7807dd8d26f5668ffbbec0360dc107bbfabd5

    echo "### Flatbufferts - cmake ###"
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=$flatbuffers_install_dir \
          -DCMAKE_C_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_CXX_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          .
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Flatbufferts - make install ###"
    make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Flatbufferts - End ###"
fi
#END flatbuffers

#BEGIN lz4
lz4_install_dir=$tmp_dir
lz4_build_dir=$build_dir/lz4
if [ ! -d $lz4_build_dir ]; then
    echo "### Lz4 - Start ###"
    mkdir -p $lz4_build_dir
    cd $lz4_build_dir
    git clone https://github.com/lz4/lz4.git
    cd lz4/
    git checkout v1.7.5

    # NOTE build Boost with old C++ ABI _GLIBCXX_USE_CXX11_ABI=0 and with -fPIC
    echo "### Lz4 - make install ###"
    CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC" CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC" PREFIX=$lz4_install_dir make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Lz4 - End ###"
fi

#END lz4

#BEGIN zstd
zstd_install_dir=$tmp_dir
zstd_build_dir=$build_dir/zstd
if [ ! -d $zstd_build_dir ]; then
    echo "### Zstd - Start ###"
    mkdir -p $zstd_build_dir
    cd $zstd_build_dir
    git clone https://github.com/facebook/zstd.git
    cd zstd/
    git checkout v1.2.0
    echo "### Zstd - cmake ###"
    cd $zstd_build_dir/zstd/build/cmake/
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=$zstd_install_dir \
          -DCMAKE_C_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_CXX_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DZSTD_BUILD_STATIC=OFF \
          .
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Zstd - make install ###"
    make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Zstd - End ###"
fi
#END zstd

#BEGIN brotli
brotli_install_dir=$tmp_dir
brotli_build_dir=$build_dir/brotli
if [ ! -d $brotli_build_dir ]; then
    echo "### Brotli - Start ###"
    mkdir -p $brotli_build_dir
    cd $brotli_build_dir
    git clone https://github.com/google/brotli.git
    cd brotli/
    git checkout v0.6.0

    echo "### Brotli - cmake ###"
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=$brotli_install_dir \
          -DCMAKE_C_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_CXX_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DBUILD_SHARED_LIBS=ON \
          .
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Brotli - make install ###"
    make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Brotli - End ###"
fi
#END brotli

#BEGIN snappy
snappy_install_dir=$tmp_dir
snappy_build_dir=$build_dir/snappy
if [ ! -d $snappy_build_dir ]; then
    echo "### Snappy - Start ###"
    mkdir -p $snappy_build_dir
    cd $snappy_build_dir
    git clone https://github.com/google/snappy.git
    cd snappy/
    git checkout 1.1.3

    # NOTE build Boost with old C++ ABI _GLIBCXX_USE_CXX11_ABI=0 and with -fPIC
    CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC -O2" CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC -O2" ./autogen.sh

    echo "### Snappy - Configure ###"
    CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC -O2" CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC -O2" ./configure --prefix=$snappy_install_dir

    echo "### Snappy - make install ###"
    CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC -O2" CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -O3 -fPIC -O2" make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Snappy - End ###"
fi
#END snappy

export CUDA_HOME=/usr/local/cuda/
export CUDACXX=$CUDA_HOME/bin/nvcc

#BEGIN arrow
arrow_install_dir=$tmp_dir
arrow_build_dir=$build_dir/arrow
echo "arrow_install_dir: "$arrow_install_dir
echo "arrow_build_dir: "$arrow_build_dir
if [ ! -d $arrow_build_dir ]; then
    echo "### Arrow - start ###"
    mkdir -p $arrow_build_dir
    cd $arrow_build_dir
    git clone https://github.com/apache/arrow.git
    cd arrow/
    git checkout apache-arrow-0.17.1

    echo "### Arrow - cmake ###"
    # NOTE for the arrow cmake arguments:
    # -DARROW_IPC=ON \ # need ipc for blazingdb-ral (because cudf)
    # -DARROW_HDFS=ON \ # blazingdb-io use arrow for hdfs
    # -DARROW_TENSORFLOW=ON \ # enable old ABI for C/C++
    
    export BOOST_ROOT=$boost_install_dir
    export FLATBUFFERS_HOME=$flatbuffers_install_dir
    export LZ4_HOME=$lz4_install_dir
    export ZSTD_HOME=$zstd_install_dir
    export BROTLI_HOME=$brotli_install_dir
    export SNAPPY_HOME=$snappy_install_dir
    export THRIFT_HOME=$thrift_install_dir

    cd cpp/
    mkdir -p build
    cd build
    cmake \
        -DARROW_BOOST_USE_SHARED=ON \
        -DARROW_BUILD_BENCHMARKS=OFF \
        -DARROW_BUILD_STATIC=OFF \
        -DARROW_BUILD_SHARED=ON \
        -DARROW_BUILD_TESTS=OFF \
        -DARROW_BUILD_UTILITIES=OFF \
        -DARROW_DATASET=ON \
        -DARROW_FLIGHT=OFF \
        -DARROW_GANDIVA=OFF \
        -DARROW_HDFS=OFF \
        -DARROW_JEMALLOC=ON \
        -DARROW_MIMALLOC=ON \
        -DARROW_ORC=OFF \
        -DCMAKE_PACKAGE_PREFIX:PATH=$tmp_dir \
        -DARROW_PARQUET=ON \
        -DARROW_PLASMA=ON \
        -DARROW_PYTHON=ON \
        -DARROW_S3=OFF \
        -DARROW_CUDA=ON \
        -DARROW_SIMD_LEVEL=NONE \
        -DARROW_WITH_BROTLI=ON \
        -DARROW_WITH_BZ2=ON \
        -DARROW_WITH_LZ4=ON \
        -DARROW_WITH_SNAPPY=ON \
        -DARROW_WITH_ZLIB=ON \
        -DARROW_WITH_ZSTD=ON \
        -DARROW_USE_LD_GOLD=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_LIBDIR=$tmp_dir/lib \
        -DCMAKE_INSTALL_PREFIX:PATH=$tmp_dir \
        ..
        # TODO Percy check llvm
        #-DLLVM_TOOLS_BINARY_DIR=$PREFIX/bin \
        #-DARROW_DEPENDENCY_SOURCE=SYSTEM \
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Arrow - make install ###"
    make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Arrow - end ###"
fi
#END arrow

# BEGIN pyarrow

export ARROW_HOME=$tmp_dir
export PARQUET_HOME=$tmp_dir
#export SETUPTOOLS_SCM_PRETEND_VERSION=$PKG_VERSION
export PYARROW_BUILD_TYPE=release
export PYARROW_WITH_DATASET=1
export PYARROW_WITH_PARQUET=1
export PYARROW_WITH_PLASMA=1
export PYARROW_WITH_CUDA=1
export PYARROW_WITH_GANDIVA=0
export PYARROW_WITH_FLIGHT=0
export PYARROW_WITH_S3=0
export PYARROW_WITH_HDFS=0
# TODO percy mario
export PYARROW_WITH_ORC=0

cd $arrow_build_dir/arrow/python
python setup.py build_ext install --single-version-externally-managed --record=record.txt


# END pyarrow

#BEGIN spdlog
spdlog_build_dir=$build_dir/spdlog
echo "spdlog_build_dir: "$spdlog_build_dir
if [ ! -d $spdlog_build_dir ]; then
    mkdir -p $spdlog_build_dir
    cd $spdlog_build_dir
    git clone https://github.com/gabime/spdlog.git
    cd spdlog/

    echo "### Spdlog - cmake ###"
    cmake -DCMAKE_INSTALL_PREFIX=$tmp_dir .
    if [ $? != 0 ]; then
      exit 1
    fi

    echo "### Spdlog - make install ###"
    make -j$MAKEJ install
    if [ $? != 0 ]; then
      exit 1
    fi
fi
#END spdlog

# NOTE percy mario this var is used by rmm build.sh and by pycudf setup.py
export PARALLEL_LEVEL=$MAKEJ

cudf_version=0.15
export CUDA_HOME=/usr/local/cuda/
alias python=python3

# BEGIN RMM
cd $build_dir
if [ ! -d rmm ]; then
    git clone https://github.com/rapidsai/rmm.git
    cd rmm
    git checkout branch-$cudf_version
    INSTALL_PREFIX=$tmp_dir CUDACXX=$CUDA_HOME/bin/nvcc ./build.sh  -v clean librmm rmm
fi
# END RMM

# BEGIN DLPACK
cd $build_dir
if [ ! -d dlpack ]; then
    git clone https://github.com/rapidsai/dlpack.git
    cd dlpack
    cmake -DCMAKE_INSTALL_PREFIX=$tmp_dir .
    make -j$MAKEJ install
fi
# END DLPACK

# BEGIN CUDF
cd $build_dir
par_build=4

if [ -z $par_build ]; then
    build_mode=4
fi

echo "==================> CUDF PAR BUILD: $build_mode"

if [ ! -d cudf ]; then
    echo "### Cudf ###"
    git clone https://github.com/rapidsai/cudf.git
    cd cudf
    git checkout branch-$cudf_version

    #git submodule update --init --remote --recursive
    #export CUDA_HOME=/usr/local/cuda/
    #export PARALLEL_LEVEL=$build_mode
    #CUDACXX=/usr/local/cuda/bin/nvcc ./build.sh
    #cmake -D GPU_ARCHS=70 -DBUILD_TESTS=ON -DCMAKE_INSTALL_PREFIX=$tmp_dir -DCMAKE_CXX11_ABI=ON ./cpp
    #echo "make"
    #make -j4 install

    export GPU_ARCH="-DGPU_ARCHS=ALL"
    export BUILD_NVTX=ON
    export BUILD_BENCHMARKS=OFF
    export BUILD_DISABLE_DEPRECATION_WARNING=ON
    export BUILD_PER_THREAD_DEFAULT_STREAM=OFF
    export ARROW_ROOT=$tmp_dir

    cd cpp
    mkdir -p build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=$tmp_dir \
          -DCMAKE_CXX11_ABI=ON \
          ${GPU_ARCH} \
          -DUSE_NVTX=${BUILD_NVTX} \
          -DBUILD_BENCHMARKS=${BUILD_BENCHMARKS} \
          -DDISABLE_DEPRECATION_WARNING=${BUILD_DISABLE_DEPRECATION_WARNING} \
          -DPER_THREAD_DEFAULT_STREAM=${BUILD_PER_THREAD_DEFAULT_STREAM} \
          -DBOOST_ROOT=$tmp_dir \
          -DBoost_NO_SYSTEM_PATHS=ON \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTS=OFF \
          ..
    make -j$MAKEJ_CUDF install
fi

# END CUDF

export CUDF_ROOT=$tmp_dir/build/cudf/cpp/build

# TODO Mario percy the user will need to do this ... for now
# add arrow libs to the lib path for arrow and pycudf
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$tmp_dir/lib

# add g++ libs to the lib path for arrow and pycudf
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib64/

# add python libs
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/


# BEGIN cudf python

cd $tmp_dir/build/cudf/python/cudf
PARALLEL_LEVEL=4 python setup.py build_ext --inplace
python setup.py install --single-version-externally-managed --record=record.txt

# END cudf python

# BEGIN dask-cudf

cd $tmp_dir/build/cudf/python/dask_cudf
python setup.py install --single-version-externally-managed --record=record.txt

# END dask-cudf

echo "end before"

exit 1

# TODO percy mario we need to think better about this
cp -rf $blazingsql_project_dir/algebra $blazingsql_build_dir
cp -rf $blazingsql_project_dir/build.sh $blazingsql_build_dir
cp -rf $blazingsql_project_dir/CHANGELOG.md $blazingsql_build_dir
cp -rf $blazingsql_project_dir/ci $blazingsql_build_dir
cp -rf $blazingsql_project_dir/comms $blazingsql_build_dir
cp -rf $blazingsql_project_dir/conda $blazingsql_build_dir
cp -rf $blazingsql_project_dir/conda-build-docker.sh $blazingsql_build_dir
cp -rf $blazingsql_project_dir/conda_build.jenkinsfile $blazingsql_build_dir
cp -rf $blazingsql_project_dir/CONTRIBUTING.md $blazingsql_build_dir
cp -rf $blazingsql_project_dir/docs $blazingsql_build_dir
cp -rf $blazingsql_project_dir/engine $blazingsql_build_dir
cp -rf $blazingsql_project_dir/io $blazingsql_build_dir
cp -rf $blazingsql_project_dir/LICENSE $blazingsql_build_dir
cp -rf $blazingsql_project_dir/print_env.sh $blazingsql_build_dir
cp -rf $blazingsql_project_dir/pyblazing $blazingsql_build_dir
cp -rf $blazingsql_project_dir/README.md $blazingsql_build_dir
cp -rf $blazingsql_project_dir/scripts $blazingsql_build_dir
cp -rf $blazingsql_project_dir/tests $blazingsql_build_dir
cp -rf $blazingsql_project_dir/test.sh $blazingsql_build_dir
cp -rf $blazingsql_project_dir/thirdparty $blazingsql_build_dir
cp -rf $blazingsql_project_dir/.clang-format $blazingsql_build_dir
cp -rf $blazingsql_project_dir/.git $blazingsql_build_dir
cp -rf $blazingsql_project_dir/.github $blazingsql_build_dir
cp -rf $blazingsql_project_dir/.gitignore $blazingsql_build_dir

#cd $blazingsql_build_dir
#./build.sh disable-aws-s3 disable-google-gs

echo "ENNNNNNNDD"




#$

exit 1
