#!/bin/sh


#############################
### Script initialization ###
#############################

echo "::group::Script initialization"

set -eu
script_dir="$(dirname "$(realpath "$0")")"
nproc="$(nproc)"

echo "::endgroup::"


####################
### Cosmopolitan ###
####################

echo "::group::Cosmopolitan"

# Build
ln -s "$(realpath ./third_party/cosmopolitan)" /opt/cosmo
cd /opt/cosmo
ape/apeinstall.sh
make -j$nproc MODE=tiny toolchain >/dev/null 2>&1
make -j$nproc m= toolchain >/dev/null 2>&1

# Install
mkdir -p /opt/cosmos/bin
ln -sf /opt/cosmo/tool/scripts/cosmocc /opt/cosmos/bin/cosmocc
ln -sf /opt/cosmo/tool/scripts/cosmoc++ /opt/cosmos/bin/cosmoc++

# Exports
export PATH="/opt/cosmos/bin:$PATH"
export CC=cosmocc
export CXX=cosmoc++
export CFLAGS="-Os -s"
export CXXFLAGS="-Os -s"

echo "::endgroup::"


###############
### libxml2 ###
###############

echo "::group::libxml2"

# Build
cd "$script_dir/third_party/libxml2"
./autogen.sh --prefix=/opt/cosmos --enable-static --disable-shared --without-zlib --without-lzma --without-python
make -j$nproc
make install

echo "::endgroup::"

###############
### libxslt ###
###############

echo "::group::libxslt"

# Build
cd "$script_dir/third_party/libxslt"
./autogen.sh --prefix=/opt/cosmos --enable-static --disable-shared --without-python
make -j$nproc
make install

echo "::endgroup::"


###############
### libslax ###
###############

echo "::group::libslax"

cd "$script_dir/third_party/libslax"

# Source Patches
curl 'https://github.com/Juniper/libslax/commit/d05cd5.patch' | git apply --reverse -
git apply $script_dir/slax.patch

# Headers
touch /opt/cosmos/include/resolv.h
mkdir -p /opt/cosmos/include/sys
cp /usr/include/x86_64-linux-gnu/sys/queue.h /opt/cosmos/include/sys/queue.h
touch /opt/cosmos/include/sys/syslog.h

# Disable extensions and tests
for loc in extensions tests; do
    mv "$loc" "$loc"_
    for file in $(find "$loc"_ -type d -printf './%P\n'); do
        mkdir -p "$loc"/$file
        cat > "$loc"/$file/Makefile.am <<EOF
.PHONY: all
all: ;
EOF
    done
done
cp -r extensions_/exslt/ extensions/
cp extensions_/Makefile.am extensions/

# Build
autoreconf --install
mkdir -p build
cd build
../configure --prefix=/opt/cosmos --disable-shared --enable-static
make -j$nproc

echo "::endgroup::"
