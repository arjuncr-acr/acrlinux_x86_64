# @author ARJUN C R (arjuncr00@acrlinux.com)
#
# web site https://www.acrlinux.com
#
#!/bin/bash

init_build_env()
{
echo "init build env...."
export VERSION="1.0"
export SCRIPT_NAME="ACR LINUX BUILD SCRIPT"
export SCRIPT_VERSION="1.0"
export LINUX_NAME="acrlinux"
export DISTRIBUTION_VERSION="2021.1"

# BASE
export KERNEL_BRANCH="5.x" 
export KERNEL_VERSION="5.6.14"
export BUSYBOX_VERSION="1.30.1"
export SYSLINUX_VERSION="6.03"

export BASEDIR=`realpath --no-symlinks $PWD`
export SOURCEDIR=${BASEDIR}/light-os
export ROOTFSDIR=${BASEDIR}/rootfs
export ISODIR=${BASEDIR}/iso
export TARGETDIR=${BASEDIR}/debian-target/rootfs_x86_64
export BASE_ROOTFS=${BASEDIR}/base-rootfs
export BUILD_OTHER_DIR="build_script_for_other"
export BOOT_SCRIPT_DIR="boot_script"
export NET_SCRIPT="network"
export CONFIG_ETC_DIR="${BASEDIR}/os-configs/etc"
export WORKSPACE="${BASEDIR}/workspace"
export BASE_SYSTEM=${BASEDIR}/acrlinux-bases-root/basesystem/

#cross compile
CROSS_COMPILE64=$BASEDIR/cross_gcc/x86_64-linux/bin/x86_64-linux-
ARCH64="x86_64"
CROSS_COMPILEi386=$BASEDIR/cross_gcc/i386-linux/bin/i386-linux-
ARCHi386="i386"

if [ "$2" == "64" ]
then
export ARCH=$ARCH64
export CROSS_COMPILE=$CROSS_COMPILE64
elif [ "$2" == "32" ]
then
export ARCH=$ARCHi386
export CROSS_COMPILE=$CROSS_COMPILEi386
else
export ARCH=$ARCH64
export CROSS_COMPILE=$CROSS_COMPILE64
fi

export ISO_FILENAME="acrlinux-${ARCH}-${VERSION}.iso"

#Dir and mode
export ETCDIR="etc"
export MODE="754"
export DIRMODE="755"
export CONFMODE="644"

#configs
export LIGHT_OS_KCONFIG="$BASEDIR/configs/kernel/light_os_kconfig"
export LIGHT_OS_BUSYBOX_CONFIG="$BASEDIR/configs/busybox/light_os_busybox_config"

#cflags
export CFLAGS=-m64
export CXXFLAGS=-m64

#setting JFLAG
if [ -z "$1"  ]
then	
	export JFLAG=4
else
	export JFLAG=$1
fi

}

prepare_dirs () {
    cd ${BASEDIR}
    if [ ! -d ${SOURCEDIR} ];
    then
        mkdir ${SOURCEDIR}
    fi
    if [ ! -d ${ROOTFSDIR} ];
    then
        mkdir ${ROOTFSDIR}
    fi
    if [ ! -d ${ISODIR} ];
    then
        mkdir    ${ISODIR}
    fi
    if [ ! -d ${WORKSPACE} ];
    then
	mkdir ${WORKSPACE}
    fi
}

build_kernel () {
    cd ${SOURCEDIR}

    if [ ! -d ${WORKSPACE}/linux-${KERNEL_VERSION} ];
    then
	    echo "copying kernel src to workspace"
	    cp -r linux-${KERNEL_VERSION} ${WORKSPACE}
	    echo "copying kernel patch to workspace"
	    cp -r kernel-patch ${WORKSPACE}
	    cd  ${WORKSPACE}/linux-${KERNEL_VERSION}
	    for patch in $(ls ../kernel-patch | grep '^[000-999]*_.*.patch'); do
		    echo "applying patch .... '$patch'."
		    patch -p1 < ../kernel-patch/${patch}
            done
    fi

    cd  ${WORKSPACE}/linux-${KERNEL_VERSION}
	
    if [ "$1" == "-c" ]
    then		    
    	make clean -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
    elif [ "$1" == "-b" ]
    then	    
    	 cp $LIGHT_OS_KCONFIG .config
	 echo "building $ARCH acrlinux kernel"
    	 make oldconfig CROSS_COMPILE=$CROSS_COMPILE ARCH=$ARCH bzImage \
        	-j ${JFLAG}
        cp arch/x86/boot/bzImage ${ISODIR}/vmlinuz-$KERNEL_VERSION-amd64
    fi   
}

build_busybox () {
    cd ${SOURCEDIR}

    if [ ! -d ${WORKSPACE}/busybox-${BUSYBOX_VERSION} ];
    then
            cp -r busybox-${BUSYBOX_VERSION} ${WORKSPACE}
	    echo "copying busybox patch to workspace"
            cp -r busybox-patch ${WORKSPACE}
            cd  ${WORKSPACE}/busybox-${BUSYBOX_VERSION}
            for patch in $(ls ../busybox-patch | grep '^[000-999]*_.*.patch'); do
                echo "applying patch .... '$patch'."
                patch -p1 < ../busybox-patch/${patch}
            done
    fi

    cd ${WORKSPACE}/busybox-${BUSYBOX_VERSION}

    if [ "$1" == "-c" ]
    then	    
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean
    elif [ "$1" == "-b" ]
    then	    
    	cp $LIGHT_OS_BUSYBOX_CONFIG .config
	echo "building $ARCH acrlinux busybox"
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE oldconfig
    	sed -i 's|.*CONFIG_STATIC.*|CONFIG_STATIC=y|' .config
    	make  ARCH=$arm CROSS_COMPILE=$CROSS_COMPILE busybox \
        	-j ${JFLAG}

    	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE install \
        	-j ${JFLAG}

    	rm -rf ${ROOTFSDIR} && mkdir ${ROOTFSDIR}
    	cd _install
    	cp -R . ${ROOTFSDIR}
    	rm  ${ROOTFSDIR}/linuxrc
    fi
}

build_extras () {
    #Build extra soft
    cd ${BASEDIR}/${BUILD_OTHER_DIR}
    if [ "$1" == "-c" ]
    then
    	./build_other_main.sh --clean
    elif [ "$1" == "-b" ]
    then
    	./build_other_main.sh --build	    
    fi	    
}

generate_rootfs () {	
   echo "generating rootfs..."
    cd ${ROOTFSDIR}

    cp  -r ${BASE_SYSTEM}/* .
     
    cp  ${ISODIR}/vmlinuz-$KERNEL_VERSION-amd64 ${ROOTFSDIR}/

    cd etc
    
    cp $BASE_ROOTFS/etc/motd .

    cp $BASE_ROOTFS/etc/hosts .
  
    cp $BASE_ROOTFS/etc/fstab .

    cp $BASE_ROOTFS/etc/mdev.conf .

    cp $BASE_ROOTFS/etc/profile .

#    install -m ${MODE}     ${BASEDIR}/${BOOT_SCRIPT_DIR}/rc.d/startup              rcS.d/startup
#    install -m ${MODE}     ${BASEDIR}/${BOOT_SCRIPT_DIR}/rc.d/shutdown             init.d/shutdown
	
    cp $BASE_ROOTFS/etc/inittab .

    cd ${ROOTFSDIR}

    #creating initial device node
    mknod -m 622 dev/console c 5 1
    mknod -m 666 dev/null c 1 3
    mknod -m 666 dev/zero c 1 5
    mknod -m 666 dev/ptmx c 5 2
    mknod -m 666 dev/tty c 5 0
    mknod -m 666 dev/tty1 c 4 1
    mknod -m 666 dev/tty2 c 4 2
    mknod -m 666 dev/tty3 c 4 3
    mknod -m 666 dev/tty4 c 4 4
    mknod -m 444 dev/random c 1 8
    mknod -m 444 dev/urandom c 1 9
    mknod -m 666 dev/ram b 1 1
    mknod -m 666 dev/mem c 1 1
    mknod -m 666 dev/kmem c 1 2

    chown root:tty dev/{console,ptmx,tty,tty1,tty2,tty3,tty4}
}


generate_image () {
    echo "generateting iso image..."

    if [ -f ${BASEDIR}/image/${ISO_FILENAME} ]
    then
	    rm ${BASEDIR}/image/${ISO_FILENAME}
    fi

    grub-mkrescue -o ${BASEDIR}/image/${ISO_FILENAME} ${ROOTFSDIR}
}

test_qemu () {
  cd ${BASEDIR}
    if [ -f ${BASEDIR}/image/${ISO_FILENAME} ];
    then
       qemu-system-x86_64 -m 128M -cdrom ${BASEDIR}/image/${ISO_FILENAME} -boot d -vga std
    fi
}

clean_files () {
   rm -rf ${SOURCEDIR}
   rm -rf ${ROOTFSDIR}
   rm -rf ${ISODIR}
   rm -rf ${WORKSPACE}
}

init_work_dir()
{
	prepare_dirs
}

clean_work_dir()
{
	clean_files
}

build_all()
{
	build_kernel  -b
#	build_busybox -b
	build_extras  -b
}

rebuild_all()
{
	clean_all
	build_all
}

clean_all()
{
	build_kernel  -c
#	build_busybox -c
	build_extras  -c
}

wipe_rebuild()
{
	clean_work_dir
	init_work_dir
	rebuild_all
}

build_img ()
{
	build_all
	generate_rootfs
	generate_image
}

help_msg()
{
echo -e "###################################################################################################\n"

echo -e "#####################################Utility-${SCRIPT_VERSION} to Build x86_64 OS####################################\n"

echo -e "###################################################################################################\n"

echo -e "Help message --help\n"

echo -e "Build and create iso: --build-img\n"

echo -e "Build All: --build-all\n"

echo -e "Rebuild All: --rebuild-all\n"

echo -e "Clean All: --clean-all\n"

echo -e "Wipe and rebuild --wipe-rebuild\n" 

echo -e "Building kernel: --build-kernel --rebuild-kernel --clean-kernel\n"

#echo -e "Building busybx: --build-busybox --rebuild-busybox --clean-busybox\n"

echo -e "Building other soft: --build-other --rebuild-other --clean-other\n"

echo -e "Creating root-fs: --create-rootfs\n"

echo -e "Create ISO Image: --create-img\n"

echo -e "Cleaning work dir: --clean-work-dir\n"

echo -e "Test with Qemu --Run-qemu\n"

echo "######################################################################################################"

}

option()
{

if [ -z "$1" ]
then
help_msg
exit 1
fi

if [ "$1" == "--build-all" ]
then	
build_all
fi

if [ "$1" == "--rebuild-all" ]
then
rebuild_all
fi

if [ "$1" == "--clean-all" ]
then
clean_all
fi

if [ "$1" == "--wipe-rebuild" ]
then
wipe_rebuild
fi

if [ "$1" == "--build-kernel" ]
then
build_kernel -b
elif [ "$1" == "--rebuild-kernel" ]
then
build_kernel -c
build_kernel -b
elif [ "$1" == "--clean-kernel" ]
then
build_kernel -c
fi

if [ "$1" == "--build-busybox" ]
then
build_busybox -b
elif [ "$1" == "--rebuild-busybox" ]
then
build_busybox -c
build_busybox -b
elif [ "$1" == "--clean-busybox" ]
then
build_busybox -c
fi

if [ "$1" == "--build-uboot" ]
then
build_uboot -b
elif [ "$1" == "--rebuild-uboot" ]
then
build_uboot -c
build_uboot -b
elif [ "$1" == "--clean-uboot" ]
then
build_uboot -c
fi

if [ "$1" == "--build-other" ]
then
build_extras -b
elif [ "$1" == "--rebuild-other" ]
then
build_extras -c
build_extras -b
elif [ "$1" == "--clean-other" ]
then
build_extras -c
fi

if [ "$1" == "--create-rootfs" ]
then
generate_rootfs
fi

if [ "$1" == "--create-img" ]
then
generate_image
fi

if [ "$1" == "--clean-work-dir" ]
then
clean_work_dir
fi

if [ "$1" == "--Run-qemu" ]
then
test_qemu
fi

if [ "$1" == "--build-img" ]
then
build_img
fi

}

main()
{
init_build_env $2 $3
init_work_dir
option $1
}

#starting of script
main $1 $2 $3 
