#!/bin/sh

if [ "${1}" == "x64" ]; then
  arch=x86_64
  archdir=x64
  cross_prefix=x86_64-w64-mingw32-
  lav_folder=LAVFilters64
  mpc_hc_folder=mpc-hc_x64
else
  arch=x86
  archdir=Win32
  cross_prefix=
  lav_folder=LAVFilters
  mpc_hc_folder=mpc-hc_x86
fi

if [ "${2}" == "Debug" ]; then
  dll_target=$(pwd)/../../../bin/${mpc_hc_folder}_Debug/${lav_folder}
  BASEDIR=$(pwd)/src/bin_${archdir}d
else
  dll_target=$(pwd)/../../../bin/${mpc_hc_folder}/${lav_folder}
  BASEDIR=$(pwd)/src/bin_${archdir}
fi

THIRDPARTYPREFIX=${BASEDIR}/thirdparty
ffmpeg_obj_target=${THIRDPARTYPREFIX}/ffmpeg
dcadec_obj_target=${THIRDPARTYPREFIX}/dcadec
lib_target=${BASEDIR}/lib
export PKG_CONFIG_PATH="${THIRDPARTYPREFIX}/lib/pkgconfig/"

make_dirs() {
  if [ ! -d ${lib_target} ]; then
    mkdir -p ${lib_target}
  fi
  if [ ! -d ${ffmpeg_obj_target} ]; then
    mkdir -p ${ffmpeg_obj_target}
  fi
  if [ ! -d ${dcadec_obj_target} ]; then
    mkdir -p ${dcadec_obj_target}
  fi
  if [ ! -d ${dll_target} ]; then
    mkdir -p ${dll_target}
  fi
}

copy_libs() {
  # install -s --strip-program=${cross_prefix}strip lib*/*-lav-*.dll ${dll_target}
  cp lib*/*-lav-*.dll ${dll_target}
  ${cross_prefix}strip ${dll_target}/*-lav-*.dll
  cp -u lib*/*.lib ${lib_target}
}

clean() {
  cd ${ffmpeg_obj_target}
  echo Cleaning...
  if [ -f config.mak ]; then
    make distclean > /dev/null 2>&1
  fi
  cd ${BASEDIR}
}

configure() {
  OPTIONS="
    --enable-shared                 \
    --disable-static                \
    --enable-version3               \
    --enable-w32threads             \
    --disable-demuxer=matroska      \
    --disable-filters               \
    --enable-filter=yadif           \
    --enable-filter=scale           \
    --disable-protocols             \
    --enable-protocol=file          \
    --enable-protocol=pipe          \
    --enable-protocol=mmsh          \
    --enable-protocol=mmst          \
    --enable-protocol=rtp           \
    --enable-protocol=http          \
    --enable-protocol=crypto        \
    --enable-protocol=rtmp          \
    --enable-protocol=rtmpt         \
    --disable-muxers                \
    --enable-muxer=spdif            \
    --disable-hwaccels              \
    --enable-hwaccel=h264_dxva2     \
    --enable-hwaccel=hevc_dxva2     \
    --enable-hwaccel=vc1_dxva2      \
    --enable-hwaccel=wmv3_dxva2     \
    --enable-hwaccel=mpeg2_dxva2    \
    --disable-decoder=dca           \
    --enable-libdcadec              \
    --enable-libspeex               \
    --enable-libopencore-amrnb      \
    --enable-libopencore-amrwb      \
    --enable-avresample             \
    --enable-avisynth               \
    --disable-avdevice              \
    --disable-postproc              \
    --disable-swresample            \
    --disable-encoders              \
    --disable-bsfs                  \
    --disable-devices               \
    --disable-programs              \
    --disable-debug                 \
    --disable-doc                   \
    --build-suffix=-lav             \
    --arch=${arch}"

  EXTRA_CFLAGS="-D_WIN32_WINNT=0x0502 -DWINVER=0x0502 -I../../../thirdparty/include -I../../../thirdparty/dcadec/libdcadec"
  EXTRA_LDFLAGS="-L${dcadec_obj_target}"
  if [ "${arch}" == "x86_64" ]; then
    OPTIONS="${OPTIONS} --enable-cross-compile --cross-prefix=${cross_prefix} --target-os=mingw32 --pkg-config=pkg-config"
    EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../../../thirdparty/lib64"
  else
    OPTIONS="${OPTIONS} --cpu=i686"
    EXTRA_CFLAGS="${EXTRA_CFLAGS} -mmmx -msse -mfpmath=sse"
    EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../../../thirdparty/lib32"
  fi

  sh ../../../ffmpeg/configure --extra-ldflags="${EXTRA_LDFLAGS}" --extra-cflags="${EXTRA_CFLAGS}" ${OPTIONS}
}

build() {
  echo Building...
  make -j$(($NUMBER_OF_PROCESSORS)) 2>&1 | tee make.log
  ## Check the return status and the log to detect possible errors
  [ ${PIPESTATUS[0]} -eq 0 ] && ! grep -q -F "rerun configure" make.log
}

configureAndBuild() {
  cd ${ffmpeg_obj_target}

  ## Don't run configure again if it was previously run
  if [ ../../ffmpeg/configure -ot config.mak ] &&
     [ ../../../build_ffmpeg.sh -ot config.mak ]; then
    echo Skipping configure...
  else
    echo Configuring...

    ## run configure, redirect to file because of a msys bug
    configure > config.out 2>&1
    CONFIGRETVAL=$?

    ## show configure output
    cat config.out
  fi

  ## Only if configure succeeded, actually build
  if [ ${CONFIGRETVAL} -eq 0 ]; then
    build &&
    copy_libs
    CONFIGRETVAL=$?
  fi

  cd ${BASEDIR}
}

build_dcadec() {
  cd ${dcadec_obj_target}
  make -f../../../thirdparty/dcadec/Makefile -j$NUMBER_OF_PROCESSORS CONFIG_WINDOWS=1 CONFIG_NDEBUG=1 CC=${cross_prefix}gcc AR=${cross_prefix}ar PREFIX=${THIRDPARTYPREFIX} lib
  cd "${BASEDIR}"
}

clean_dcadec() {
  cd ${dcadec_obj_target}
  make -f../../../thirdparty/dcadec/Makefile CONFIG_WINDOWS=1 clean
  cd ${BASEDIR}
}

echo Building ffmpeg in GCC ${arch} Release config...

make_dirs

cd ${BASEDIR}

CONFIGRETVAL=0

if [ "${3}" == "Clean" ]; then
  clean_dcadec
  clean
  CONFIGRETVAL=$?
else
  ## Check if configure was previously run
  if [ -f config.mak ]; then
    CLEANBUILD=0
  else
    CLEANBUILD=1
  fi

  build_dcadec

  configureAndBuild

  ## In case of error and only if we didn't start with a clean build,
  ## we try to rebuild from scratch including a full reconfigure
  if [ ! ${CONFIGRETVAL} -eq 0 ] && [ ${CLEANBUILD} -eq 0 ]; then
    echo Trying again with forced reconfigure...
    clean_dcadec && build_dcadec
    clean && configureAndBuild
  fi
fi

cd ../../..

exit ${CONFIGRETVAL}
