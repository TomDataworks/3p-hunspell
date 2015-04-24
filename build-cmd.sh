#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

HUNSPELL_VERSION="1.3.3"
HUNSPELL_SOURCE_DIR="hunspell"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"

echo "${HUNSPELL_VERSION}" > "${stage}/VERSION.txt"

pushd "$HUNSPELL_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars

            build_sln "src/win_api/hunspell.sln" "Debug_dll|Win32" "libhunspell"
            build_sln "src/win_api/hunspell.sln" "Release_dll|Win32" "libhunspell"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp src/win_api/Debug_dll/libhunspell/libhunspell{.dll,.lib,.pdb} "$stage/lib/debug"
            cp src/win_api/Release_dll/libhunspell/libhunspell{.dll,.lib,.pdb} "$stage/lib/release"
        ;;
        "windows64")
            load_vsvars

            build_sln "src/win_api/hunspell.sln" "Debug_dll|x64" "libhunspell"
            build_sln "src/win_api/hunspell.sln" "Release_dll|x64" "libhunspell"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp src/win_api/x64/Debug_dll/libhunspell{.dll,.lib,.pdb} "$stage/lib/debug"
            cp src/win_api/x64/Release_dll/libhunspell{.dll,.lib,.pdb} "$stage/lib/release"
        ;;
        "darwin")
            DEVELOPER=$(xcode-select --print-path)
            opts='-arch i386 -arch x86_64 -iwithsysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk -mmacosx-version-min=10.8'
			export CC="clang"
            export CXX="clang++ -stdlib=libc++ -std=c++11"
            export CFLAGS="$opts"
            export CXXFLAGS="$opts"
            export LDFLAGS="$opts -stdlib=libc++"
            ./configure --prefix="$stage" --with-experimental
            make
            make install
            mkdir -p "$stage/lib/release"
            mv "$stage/lib/"{*.a,*.dylib,*.alias} "$stage/lib/release"
            pushd "$stage/lib/release"
              fix_dylib_id libhunspell-1.3.0.dylib
            popd
        ;;
        "linux")
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector-strong -D_FORTIFY_SOURCE=2"
            CFLAGS="-m32 -Og -g" CXXFLAGS="-m32 -Og -g -std=c++11" ./configure --with-pic --prefix="$stage" --libdir="$stage/lib/debug"
            make -j$JOBS
            make install

            make distclean

            CFLAGS="-m32 -O3 -g $HARDENED" CXXFLAGS="-m32 -O3 -g $HARDENED -std=c++11" ./configure --with-pic --prefix="$stage" --libdir="$stage/lib/release"
            make -j$JOBS
            make install

            make distclean
        ;;
        "linux64")
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector-strong -D_FORTIFY_SOURCE=2"
            CFLAGS="-m64 -Og -g" CXXFLAGS="-m64 -Og -g -std=c++11" ./configure --with-pic --prefix="$stage" --libdir="$stage/lib/debug"
            make -j$JOBS
            make install

            make distclean

            CFLAGS="-m64 -O3 -g $HARDENED" CXXFLAGS="-m64 -O3 -g $HARDENED -std=c++11" ./configure --with-pic --prefix="$stage" --libdir="$stage/lib/release"
            make -j$JOBS
            make install

            make distclean
        ;;
    esac
    mkdir -p "$stage/include/hunspell"
    cp src/hunspell/{*.h,*.hxx} "$stage/include/hunspell"
    cp src/win_api/hunspelldll.h "$stage/include/hunspell"
    mkdir -p "$stage/LICENSES"
    cp "license.hunspell" "$stage/LICENSES/hunspell.txt"
    cp "license.myspell" "$stage/LICENSES/myspell.txt"
popd

pass
