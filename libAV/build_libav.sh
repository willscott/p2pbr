#!/bin/sh

#  build_libav.sh
#  p2pbr
#
# Adapted from https://gist.github.com/1162907
# Help from https://github.com/yuvi/gas-preprocessor/issues/16
[ "$SOURCE_ROOT" ] && cd $SOURCE_ROOT || cd ..
cd libAV/libAV

if [ -e "compiled/fat/lib/libavformat.a" ]; then
  exit 0;
fi

export PATH=$PATH:../gas

# configure for armv7 build
./configure \
--prefix=compiled/armv7 \
--disable-doc \
--disable-debug \
--disable-avplay \
--disable-avserver \
--disable-avprobe \
--disable-asm \
--disable-everything \
\
--enable-muxer=mpegts \
\
--enable-cross-compile \
--arch=arm \
--cpu=cortex-a8 \
--target-os=darwin \
--cc=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc \
--as='../gas/gas-preprocessor.pl /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc' \
--sysroot=/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk \
--extra-cflags="-w -arch armv7 -mfpu=neon " \
--extra-ldflags="-arch armv7 -mfpu=neon -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk" \
--enable-pic

# build for armv7
make clean
make && make install

# configure for i386 build
./configure \
--prefix=compiled/i386 \
--disable-doc \
--disable-debug \
--disable-avplay \
--disable-avserver \
--disable-avprobe \
--disable-asm \
--disable-everything \
\
--enable-muxer=mpegts \
\
--enable-cross-compile \
--arch=i386 \
--cpu=i386 \
--target-os=darwin \
--cc=/Developer/usr/bin/gcc \
--as='../gas/gas-preprocessor.pl /Developer/usr/bin/gcc' \
--sysroot=/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk \
--extra-cflags="-w -arch i386 " \
--extra-ldflags="-arch i386 -isysroot /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk" \
--disable-pic \
--disable-neon

# build for i386
make clean
make && make install

# make fat (universal) libs
mkdir -p ./compiled/fat/lib

lipo -output ./compiled/fat/lib/libavcodec.a  -create \
-arch armv7 ./compiled/armv7/lib/libavcodec.a \
-arch i386 ./compiled/i386/lib/libavcodec.a

lipo -output ./compiled/fat/lib/libavdevice.a  -create \
-arch armv7 ./compiled/armv7/lib/libavdevice.a \
-arch i386 ./compiled/i386/lib/libavdevice.a

lipo -output ./compiled/fat/lib/libavfilter.a  -create \
-arch armv7 ./compiled/armv7/lib/libavfilter.a \
-arch i386 ./compiled/i386/lib/libavfilter.a

lipo -output ./compiled/fat/lib/libavformat.a  -create \
-arch armv7 ./compiled/armv7/lib/libavformat.a \
-arch i386 ./compiled/i386/lib/libavformat.a

lipo -output ./compiled/fat/lib/libavutil.a  -create \
-arch armv7 ./compiled/armv7/lib/libavutil.a \
-arch i386 ./compiled/i386/lib/libavutil.a

lipo -output ./compiled/fat/lib/libswscale.a  -create \
-arch armv7 ./compiled/armv7/lib/libswscale.a \
-arch i386 ./compiled/i386/lib/libswscale.a