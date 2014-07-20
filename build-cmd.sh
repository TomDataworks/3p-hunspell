#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

HUNSPELL_VERSION="1.3.2"
HUNSPELL_SOURCE_DIR="hunspell-1.3.2"

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
pushd "$HUNSPELL_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars

            build_sln "src/win_api/hunspell.sln" "Debug_dll|Win32"
            build_sln "src/win_api/hunspell.sln" "Release_dll|Win32"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp src/win_api/Debug_dll/libhunspell/libhunspell{.dll,.lib,.pdb} "$stage/lib/debug"
            cp src/win_api/Release_dll/libhunspell/libhunspell{.dll,.lib,.pdb} "$stage/lib/release"
        ;;
        "windows64")
            load_vsvars

            build_sln "src/win_api/hunspell.sln" "Debug_dll|x64"
            build_sln "src/win_api/hunspell.sln" "Release_dll|x64"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp src/win_api/x64/Debug_dll/libhunspell{.dll,.lib,.pdb} "$stage/lib/debug"
            cp src/win_api/x64/Release_dll/libhunspell{.dll,.lib,.pdb} "$stage/lib/release"
        ;;
        "darwin")
            DEVELOPER=$(xcode-select --print-path)
            opts='-arch i386 -arch x86_64 -iwithsysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk -mmacosx-version-min=10.7'
            export CFLAGS="$opts"
            export CXXFLAGS="$opts"
            export LDFLAGS="$opts"
            ./configure --prefix="$stage"
            make
            make install
            mkdir -p "$stage/lib/release"
            mv "$stage/lib/"{*.a,*.dylib,*.alias} "$stage/lib/release"
            pushd "$stage/lib/release"
              fix_dylib_id libhunspell-1.3.0.dylib
            popd
        ;;
        "linux")
            CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage"
            make
            make install
            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
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
