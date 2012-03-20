RELEASE=2.0

KERNEL_VER=2.6.32
PKGREL=63
# also include firmware of previous versrion into 
# the fw package:  fwlist-2.6.32-PREV-pve
KREL=10

RHKVER=220.4.1.el6
OVZVER=042stab049.6

KERNELSRCRPM=vzkernel-${KERNEL_VER}-${OVZVER}.src.rpm

EXTRAVERSION=-${KREL}-pve
KVNAME=${KERNEL_VER}${EXTRAVERSION}
PACKAGE=pve-kernel-${KVNAME}
HDRPACKAGE=pve-headers-${KVNAME}

ARCH=amd64
TOP=$(shell pwd)

KERNEL_SRC=linux-2.6-${KERNEL_VER}
RHKERSRCDIR=rh-kernel-src
KERNEL_CFG=config-${KERNEL_VER}
KERNEL_CFG_ORG=config-${KERNEL_VER}-${OVZVER}.x86_64

FW_VER=1.0
FW_REL=15
FW_DEB=pve-firmware_${FW_VER}-${FW_REL}_all.deb

AOEDIR=aoe6-77
AOESRC=${AOEDIR}.tar.gz

E1000EDIR=e1000e-1.9.5
E1000ESRC=${E1000EDIR}.tar.gz

IGBDIR=igb-3.3.6
IGBSRC=${IGBDIR}.tar.gz

IXGBEDIR=ixgbe-3.7.17
IXGBESRC=${IXGBEDIR}.tar.gz

#ARECADIR=arcmsr.1.20.0X.15-110330
#ARECASRC=${ARECADIR}.zip

ISCSITARGETDIR=iscsitarget-1.4.20.2
ISCSITARGETSRC=${ISCSITARGETDIR}.tar.gz

DST_DEB=${PACKAGE}_${KERNEL_VER}-${PKGREL}_${ARCH}.deb
HDR_DEB=${HDRPACKAGE}_${KERNEL_VER}-${PKGREL}_${ARCH}.deb
PVEPKG=proxmox-ve-${KERNEL_VER}
PVE_DEB=${PVEPKG}_${RELEASE}-${PKGREL}_all.deb

all: check_gcc ${DST_DEB} ${PVE_DEB} ${FW_DEB} ${HDR_DEB}

${PVE_DEB} pve: proxmox-ve/control proxmox-ve/postinst
	rm -rf proxmox-ve/data
	mkdir -p proxmox-ve/data/DEBIAN
	mkdir -p proxmox-ve/data/usr/share/doc/${PVEPKG}/
	install -m 0644 proxmox-ve/proxmox-release\@proxmox.com.pubkey proxmox-ve/data/usr/share/doc/${PVEPKG}
	sed -e 's/@KVNAME@/${KVNAME}/' -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@RELEASE@/${RELEASE}/' -e 's/@PKGREL@/${PKGREL}/' <proxmox-ve/control >proxmox-ve/data/DEBIAN/control
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' <proxmox-ve/postinst >proxmox-ve/data/DEBIAN/postinst
	chmod 0755 proxmox-ve/data/DEBIAN/postinst
	install -m 0644 proxmox-ve/copyright proxmox-ve/data/usr/share/doc/${PVEPKG}
	install -m 0644 proxmox-ve/changelog.Debian proxmox-ve/data/usr/share/doc/${PVEPKG}
	gzip --best proxmox-ve/data/usr/share/doc/${PVEPKG}/changelog.Debian
	dpkg-deb --build proxmox-ve/data ${PVE_DEB}

check_gcc: 
	gcc --version|grep "4.4.5" || false

${DST_DEB}: data control.in postinst.in
	mkdir -p data/DEBIAN
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@KVNAME@/${KVNAME}/' -e 's/@PKGREL@/${PKGREL}/' <control.in >data/DEBIAN/control
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <postinst.in >data/DEBIAN/postinst
	chmod 0755 data/DEBIAN/postinst
	install -D -m 644 copyright data/usr/share/doc/${PACKAGE}/copyright
	install -D -m 644 changelog.Debian data/usr/share/doc/${PACKAGE}/changelog.Debian
	gzip -f --best data/usr/share/doc/${PACKAGE}/changelog.Debian
	rm -f data/lib/modules/${KVNAME}/source
	rm -f data/lib/modules/${KVNAME}/build
	dpkg-deb --build data ${DST_DEB}
	lintian ${DST_DEB}


fwlist-${KVNAME}: data
	./find-firmware.pl data/lib/modules/${KVNAME} >fwlist.tmp
	mv fwlist.tmp $@

data: .compile_mark ${KERNEL_CFG} aoe.ko e1000e.ko igb.ko ixgbe.ko iscsi_trgt.ko
	rm -rf data tmp; mkdir -p tmp/lib/modules/${KVNAME}
	mkdir tmp/boot
	install -m 644 ${KERNEL_CFG} tmp/boot/config-${KVNAME}
	install -m 644 ${KERNEL_SRC}/System.map tmp/boot/System.map-${KVNAME}
	install -m 644 ${KERNEL_SRC}/arch/x86_64/boot/bzImage tmp/boot/vmlinuz-${KVNAME}
	cd ${KERNEL_SRC}; make INSTALL_MOD_PATH=../tmp/ modules_install
	# install latest aoe driver
	install -m 644 aoe.ko tmp/lib/modules/${KVNAME}/kernel/drivers/block/aoe/aoe.ko
	# install latest ixgbe driver
	install -m 644 ixgbe.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ixgbe/
	# install latest e1000e driver
	install -m 644 e1000e.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/e1000e/
	# install latest ibg driver
	install -m 644 igb.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/igb/
	# install areca driver
	#install -m 644 arcmsr.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/arcmsr/
	# install iscsitarget module
	install -m 644 -D iscsi_trgt.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/iscsi_trgt.ko
	# remove firmware
	rm -rf tmp/lib/firmware
	# strip debug info
	find tmp/lib/modules -name \*.ko -print | while read f ; do strip --strip-debug "$$f"; done
	# finalize
	depmod -b tmp/ ${KVNAME}
	mv tmp data

.compile_mark: ${KERNEL_SRC}/README ${KERNEL_CFG}
	cp ${KERNEL_CFG} ${KERNEL_SRC}/.config
	cd ${KERNEL_SRC}; make oldconfig
	cd ${KERNEL_SRC}; make -j 8
	touch $@

${KERNEL_CFG}: ${KERNEL_CFG_ORG} config-${KERNEL_VER}.diff
	cp ${KERNEL_CFG_ORG} ${KERNEL_CFG}.new
	patch --no-backup ${KERNEL_CFG}.new config-${KERNEL_VER}.diff
	mv ${KERNEL_CFG}.new ${KERNEL_CFG}

${KERNEL_SRC}/README: ${KERNEL_SRC}.org/README
	rm -rf ${KERNEL_SRC}
	cp -a ${KERNEL_SRC}.org ${KERNEL_SRC}
	cd ${KERNEL_SRC}; patch -p1 <../bootsplash-3.1.9-2.6.31-rh.patch
	cd ${KERNEL_SRC}; patch -p1 <../${RHKERSRCDIR}/patch-042stab049
	cd ${KERNEL_SRC}; patch -p1 <../do-not-use-barrier-on-ext3.patch
	cd ${KERNEL_SRC}; patch -p1 <../bridge-patch.diff
	cd ${KERNEL_SRC}; patch -p1 <../fix-aspm-policy.patch
	cd ${KERNEL_SRC}; patch -p1 <../optimize-cfq-parameters.patch
	sed -i ${KERNEL_SRC}/Makefile -e 's/^EXTRAVERSION.*$$/EXTRAVERSION=${EXTRAVERSION}/'
	touch $@

${KERNEL_SRC}.org/README: ${RHKERSRCDIR}/kernel.spec ${RHKERSRCDIR}/linux-${KERNEL_VER}-${RHKVER}.tar.bz2
	rm -rf ${KERNEL_SRC}.org linux-${KERNEL_VER}-${RHKVER}
	tar xf ${RHKERSRCDIR}/linux-${KERNEL_VER}-${RHKVER}.tar.bz2
	mv linux-${KERNEL_VER}-${RHKVER} ${KERNEL_SRC}.org
	touch $@

${RHKERSRCDIR}/kernel.spec: ${KERNELSRCRPM}
	rm -rf ${RHKERSRCDIR}
	mkdir ${RHKERSRCDIR}
	cd ${RHKERSRCDIR};rpm2cpio ../${KERNELSRCRPM} |cpio -i
	touch $@

aoe.ko aoe: .compile_mark ${AOESRC}
	# aoe driver updates
	rm -rf ${AOEDIR} aoe.ko
	tar xf ${AOESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${AOEDIR}; make KVER=${KVNAME}
	cp ${AOEDIR}/linux/drivers/block/aoe/aoe.ko aoe.ko

e1000e.ko e1000e: ${E1000ESRC}
	rm -rf ${E1000EDIR}
	tar xf ${E1000ESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${E1000EDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${E1000EDIR}/src/e1000e.ko e1000e.ko

igb.ko igb: ${IGBSRC}
	rm -rf ${IGBDIR}
	tar xf ${IGBSRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${IGBDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${IGBDIR}/src/igb.ko igb.ko

ixgbe.ko ixgbe: ${IXGBESRC}
	rm -rf ${IXGBEDIR}
	tar xf ${IXGBESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${IXGBEDIR}/src; make CFLAGS_EXTRA="-DIXGBE_NO_LRO" BUILD_KERNEL=${KVNAME}
	cp ${IXGBEDIR}/src/ixgbe.ko ixgbe.ko

#arcmsr.ko: ${ARECASRC}
#	rm -rf ${ARECADIR}
#	unzip ${ARECASRC}
#	mkdir -p /lib/modules/${KVNAME}
#	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
#	cd ${ARECADIR}; make -C ${TOP}/${KERNEL_SRC} CONFIG_SCSI_ARCMSR=m SUBDIRS=${TOP}/${ARECADIR} modules
#	cp ${ARECADIR}/arcmsr.ko arcmsr.ko

iscsi_trgt.ko: ${ISCSITARGETSRC}
	rm -rf ${ISCSITARGETDIR}
	tar xf ${ISCSITARGETSRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${ISCSITARGETDIR}; make KVER=${KVNAME}
	cp ${ISCSITARGETDIR}/kernel/iscsi_trgt.ko iscsi_trgt.ko

headers_tmp := $(CURDIR)/tmp-headers
headers_dir := $(headers_tmp)/usr/src/linux-headers-${KVNAME}

${HDR_DEB} hdr: .compile_mark headers-control.in headers-postinst.in
	rm -rf $(headers_tmp)
	install -d $(headers_tmp)/DEBIAN $(headers_dir)/include/
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@KVNAME@/${KVNAME}/' -e 's/@PKGREL@/${PKGREL}/' <headers-control.in >$(headers_tmp)/DEBIAN/control
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <headers-postinst.in >$(headers_tmp)/DEBIAN/postinst
	chmod 0755 $(headers_tmp)/DEBIAN/postinst
	install -D -m 644 copyright $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/copyright
	install -D -m 644 changelog.Debian $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/changelog.Debian
	gzip -f --best $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/changelog.Debian
	install -m 0644 ${KERNEL_SRC}/.config $(headers_dir)
	install -m 0644 ${KERNEL_SRC}/Module.symvers $(headers_dir)
	cd ${KERNEL_SRC}; find . -path './debian/*' -prune -o -path './include/*' -prune -o -path './Documentation' -prune \
	  -o -path './scripts' -prune -o -type f \
	  \( -name 'Makefile*' -o -name 'Kconfig*' -o -name 'Kbuild*' -o \
	     -name '*.sh' -o -name '*.pl' \) \
	  -print | cpio -pd --preserve-modification-time $(headers_dir)
	cd ${KERNEL_SRC}; cp -a include scripts $(headers_dir)
	cd ${KERNEL_SRC}; (find arch/x86 -name include -type d -print | \
		xargs -n1 -i: find : -type f) | \
		cpio -pd --preserve-modification-time $(headers_dir)
	dpkg-deb --build $(headers_tmp) ${HDR_DEB}
	#lintian ${HDR_DEB}

linux-firmware.git/WHENCE:
	git clone git://git.kernel.org/pub/scm/linux/kernel/git/dwmw2/linux-firmware.git linux-firmware.git

${FW_DEB} fw: control.firmware linux-firmware.git/WHENCE changelog.firmware fwlist-2.6.18-2-pve fwlist-2.6.24-12-pve fwlist-2.6.32-3-pve fwlist-2.6.32-4-pve fwlist-2.6.32-5-pve fwlist-2.6.32-6-pve fwlist-2.6.35-1-pve fwlist-${KVNAME}
	rm -rf fwdata
	mkdir -p fwdata/lib/firmware
	./assemble-firmware.pl fwlist-${KVNAME} fwdata/lib/firmware
	# include any files from older/newer kernels here
	./assemble-firmware.pl fwlist-2.6.24-12-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.18-2-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-3-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-4-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-5-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-6-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.35-1-pve fwdata/lib/firmware
	install -d fwdata/usr/share/doc/pve-firmware
	cp linux-firmware.git/WHENCE fwdata/usr/share/doc/pve-firmware/README
	install -d fwdata/usr/share/doc/pve-firmware/licenses
	cp linux-firmware.git/LICEN[CS]E* fwdata/usr/share/doc/pve-firmware/licenses
	install -D -m 0644 changelog.firmware fwdata/usr/share/doc/pve-firmware/changelog.Debian
	gzip -9 fwdata/usr/share/doc/pve-firmware/changelog.Debian	
	install -d fwdata/DEBIAN
	sed -e 's/@VERSION@/${FW_VER}-${FW_REL}/' <control.firmware >fwdata/DEBIAN/control
	dpkg-deb --build fwdata ${FW_DEB}

.PHONY: upload
upload: ${DST_DEB} ${PVE_DEB} ${HDR_DEB} ${FW_DEB}
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o rw 
	mkdir -p /pve/${RELEASE}/extra
	mkdir -p /pve/${RELEASE}/install
	rm -rf /pve/${RELEASE}/extra/${PACKAGE}_*.deb
	rm -rf /pve/${RELEASE}/extra/${HDRPACKAGE}_*.deb
	rm -rf /pve/${RELEASE}/extra/${PVEPKG}_*.deb
	rm -rf /pve/${RELEASE}/extra/pve-firmware*.deb
	rm -rf /pve/${RELEASE}/extra/Packages*
	cp ${DST_DEB} ${PVE_DEB} ${HDR_DEB} ${FW_DEB} /pve/${RELEASE}/extra
	cd /pve/${RELEASE}/extra; dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o ro

.PHONY: distclean
distclean: clean
	rm -rf linux-firmware.git linux-firmware-from-kernel.git ${KERNEL_SRC}.org ${RHKERSRCDIR}

.PHONY: clean
clean:
	rm -rf *~ .compile_mark ${KERNEL_CFG} ${KERNEL_SRC} tmp data proxmox-ve/data *.deb ${AOEDIR} aoe.ko ${headers_tmp} fwdata fwlist.tmp *.ko ${IXGBEDIR} ${E1000EDIR} e1000e.ko ${IGBDIR} igb.ko fwlist-${KVNAME} iscsi_trgt.ko ${ISCSITARGETDIR}



