#!/bin/sh
sudo apt-get install libboost-dev libsuperlu4 libcgal-dev libminizip-dev
INSTALL_DIR=$PWD/meshmixer

# Compile patchelf 
mkdir -p tmp
PATCHELF=tmp/patchelf/src/patchelf
if [ ! -f $PATCHELF ]; then
  (cd tmp && git clone https://github.com/NixOS/patchelf && cd patchelf && ./bootstrap.sh && ./configure && make)
fi

# Download meshmixer
mkdir -p $INSTALL_DIR
if [ ! -f tmp/meshmixer_2.9_amd64.deb ]; then 
  curl https://s3.amazonaws.com/autodesk-meshmixer/meshmixer/amd64/meshmixer_2.9_amd64.deb > tmp/meshmixer_2.9_amd64.deb
fi
dpkg -x tmp/meshmixer_2.9_amd64.deb $INSTALL_DIR

# Patch meshmixer binary and libraries to search in the relative path ../lib relative to the meshmixer binary
$PATCHELF --set-rpath '$ORIGIN/../lib' $INSTALL_DIR/usr/bin/meshmixer
find $INSTALL_DIR/usr/lib -name *.so -exec $PATCHELF --set-rpath '$ORIGIN/../lib' '{}' \;

# Setup symbolic links to newer versions of libCGAL and libsuperlu
ln -s /usr/lib/x86_64-linux-gnu/libCGAL.so.11.0.1 $INSTALL_DIR/usr/lib/libCGAL.so.10
ln -s /usr/lib/x86_64-linux-gnu/libsuperlu.so.4 $INSTALL_DIR/usr/lib/libsuperlu.so.3

# Grab libboost 1.54.0
curl http://mirrors.kernel.org/ubuntu/pool/main/b/boost1.54/libboost-date-time1.54.0_1.54.0-4ubuntu3_amd64.deb > tmp/libboost-date-time.deb
curl http://mirrors.kernel.org/ubuntu/pool/main/b/boost1.54/libboost-system1.54.0_1.54.0-4ubuntu3_amd64.deb > tmp/libboost-system.deb
curl http://mirrors.kernel.org/ubuntu/pool/main/b/boost1.54/libboost-filesystem1.54.0_1.54.0-4ubuntu3_amd64.deb > tmp/libboost-filesystem.deb
curl http://mirrors.kernel.org/ubuntu/pool/main/b/boost1.54/libboost-thread1.54.0_1.54.0-4ubuntu3_amd64.deb > tmp/libboost-thread.deb

dpkg -x tmp/libboost-date-time.deb tmp/libboost
dpkg -x tmp/libboost-system.deb tmp/libboost
dpkg -x tmp/libboost-filesystem.deb tmp/libboost
dpkg -x tmp/libboost-thread.deb tmp/libboost

# Copy libboost 1.54 into meshmixer/usr/lib
rsync -auv tmp/libboost/usr/lib/x86_64-linux-gnu/lib* $INSTALL_DIR/usr/lib/

# Fix incorrect version in desktop file
sed -i 's/Version=2.7/Version=1.0/g' $INSTALL_DIR/usr/share/applications/meshmixer.desktop
#sed -i "s#Exec=#Exec=${INSTALL_DIR}/#g" $INSTALL_DIR/usr/share/applications/meshmixer.desktop

# Install meshmixer application icon and other global state into usr/share
sudo rsync -auv $INSTALL_DIR/usr/share/ /usr/share

# Setup user meshmixer directory in Documents or it will complain on startup
rsync -auv $INSTALL_DIR/usr/share/meshmixer ~/Documents

# Setup symbolic link in /usr/bin
sudo ln -sf $INSTALL_DIR/usr/bin/meshmixer /usr/bin/meshmixer

# Delete scratch directory
rm -rf tmp