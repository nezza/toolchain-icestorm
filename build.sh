#!/bin/bash
##################################
#   Icestorm toolchain builder   #
##################################

# Generate toolchain-icestorm-arch-ver.tar.gz from source code
# sources: http://www.clifford.at/icestorm/

VERSION=8

# -- Target architectures
ARCHS=( linux_x86_64 )
# ARCH = (linux_x86_64 linux_i686 linux_armv7l linux_aarch64 darwin windows)

# -- Toolchain name
NAME=toolchain-icestorm

# -- Debug flags
COMPILE_ICESTORM=1
COMPILE_ARACHNE=0
COMPILE_YOSYS=0
COMPILE_YOSYS_ABC=0
CREATE_PACKAGE=1

# -- Git url were to retieve the upstream sources
GIT_ICESTORM=https://github.com/cliffordwolf/icestorm.git
GIT_ARACHNE=https://github.com/cseed/arachne-pnr.git
REL_YOSYS=https://github.com/cliffordwolf/yosys/archive/yosys-0.6.tar.gz

# -- Store current dir
WORK_DIR=$PWD
# -- Folder for building the source code
BUILDS_DIR=$WORK_DIR/builds
# -- Folder for storing the generated packages
PACKAGES_DIR=$WORK_DIR/packages
# --  Folder for storing the source code from github
UPSTREAM_DIR=$WORK_DIR/upstream

# -- Create the build directory
mkdir -p $BUILDS_DIR
# -- Create the packages directory
mkdir -p $PACKAGES_DIR
# -- Create the upstream directory and enter into it
mkdir -p $UPSTREAM_DIR

# -- Test script function
function test_bin {
  bash $WORK_DIR/test/test_bin.sh $1
}


# -- Icestorm directory
ICESTORM=icestorm
ARACHNE=arachne-pnr


# -- Loop
for ARCH in ${ARCHS[@]}
do

  # -- Directory for compiling the tools
  BUILD_DIR=$BUILDS_DIR/build_$ARCH

  # -- Directory for installation the target files
  PACKAGE_DIR=$PACKAGES_DIR/build_$ARCH

  # --- Directory where the files for patching the upstream are located
  DATA=$WORK_DIR/build-data/$ARCH

  # -- Remove the build dir and the generated packages then exit
  if [ "$1" == "clean" ]; then

    # -- Remove the final package
    rm -r -f $PACKAGE_DIR

    # -- Remove the build dir
    rm -r -f $BUILD_DIR

    echo "-----> CLEAN"
    exit
  fi

  # -- Install dependencies
  echo "Installing dependencies..."
  sudo apt-get install build-essential clang bison flex libreadline-dev \
                       gawk tcl-dev libffi-dev git mercurial graphviz   \
                       xdot pkg-config python python3 libftdi1-dev # <- ver 1!

  # -- Create the build dir
  mkdir -p $BUILD_DIR

  # -- Create the package folders
  mkdir -p $PACKAGE_DIR/$NAME/bin
  mkdir -p $PACKAGE_DIR/$NAME/share

  # --------- Compile icestorm ---------------------------------------
  if [ $COMPILE_ICESTORM == "1" ]; then

      cd $UPSTREAM_DIR

      # -- Clone the toolchain from the github
      git -C $ICESTORM pull || git clone --depth=1 $GIT_ICESTORM $ICESTORM

      # -- Copy the upstream sources into the build directory
      rsync -a $ICESTORM $BUILD_DIR --exclude .git

      cd $BUILD_DIR/$ICESTORM

      # -- Apply the patches
      cp $DATA/Makefile.iceprog $BUILD_DIR/$ICESTORM/iceprog/Makefile
      # ...

      # -- Compile it
      make -j$(( $(nproc) -1)) STATIC=1 -C iceprog
      make -j$(( $(nproc) -1)) STATIC=1 -C icepack
      make -j$(( $(nproc) -1)) STATIC=1 -C icetime

      # -- Test the generated executables
      test_bin iceprog/iceprog
      test_bin icepack/icepack
      test_bin icetime/icetime

      # -- Copy the executables to the bin dir
      cp iceprog/iceprog $PACKAGE_DIR/$NAME/bin
      cp icepack/icepack $PACKAGE_DIR/$NAME/bin
      cp icetime/icetime $PACKAGE_DIR/$NAME/bin

  fi

  # ---------------------- Create the package --------------------------
  if [ $CREATE_PACKAGE == "1" ]; then

    # --Tarball name
    TARBALL=$NAME-$ARCH-$VERSION.tar.gz

    cd $PACKAGE_DIR
    tar vzcf $TARBALL $NAME
  fi

done
