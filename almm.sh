#!/usr/bin/env bash

# Avouch Linux Live iso maker

### change to english locale!
export LANG="en_US"


DE="${1}"
USERNAME="liveuser"
DATADIR="${PWD}/data"
BASEDIR="${PWD}/${DE}"
WORK="${BASEDIR}/work"
LIVECD="${BASEDIR}/livecd"
FORMAT="squashfs"
FSDIR="LiveOS"
# FILESYSTEM="ext3"
# FSIMAGENAME="ext3fs"
FILESYSTEM="btrfs"
FSIMAGENAME="rootfs"
ISODIR="${BASEDIR}/iso"
MOUNTPOINT="${WORK}/${FSIMAGENAME}"
CHROOTDIR=$(readlink -m $MOUNTPOINT)
DRIVE="${WORK}/squashfs/LiveOS/${FSIMAGENAME}.img"
DRIVE_SIZE=11264

ARCH="$(uname -m)"
BASENAME="$(basename "${PWD}")"

# KERNVER=$(uname -r)
# KERNVER="5.8.0-1-avouch"
AVH_REL_STRING="Avouch release 0.2.0"

########################################################################
# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW

	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[0m"
		BOLD="\e[1m"
		BLUE="${BOLD}\e[34m"
		GREEN="${BOLD}\e[32m"
		RED="${BOLD}\e[31m"
		YELLOW="${BOLD}\e[33m"
	fi

readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

### SUBROUTINES ###
plain() {
	local mesg=$1; shift
	printf "${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

success() {
	local mesg=$1; shift
	printf "${GREEN} $(gettext "Success:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

message() {
	local mesg=$1; shift
	printf "${BLUE} $(gettext "Message:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW} $(gettext "Warning:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED} $(gettext "Error:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}
########################################################################

# chroot_mount()
# prepares target system as a chroot
#
### check for root
check_root () {
	
	if test "x`id -u`" != "x0"; then
		echo "Root privileges are required for running ali."	
		exit 1
	fi
}

### check for the desired Desktop Environment
if [ -n "${DE}" ]; then
	if [[ "${DE}" == "gnome" ]]; then
		ISONAME="Avouch-Live-Gnome-0.2.0-x86_64"
		ISOLABEL="Avouch-Live"
		message "Live OS based on Gnome will be created"
	elif [[ "${DE}" == "plasma" ]];  then
		ISONAME="Avouch-Live-Plasma-0.2.0-x86_64"
		ISOLABEL="Avouch-Live"
		message "Live OS based on Plasma will be created"
	elif [[ "${DE}" == "xfce" ]];  then
		ISONAME="Avouch-Live-Xfce-0.2.0-x86_64"
		ISOLABEL="Avouch-Live"
		message "Live OS based on Xfce will be created"
	elif [[ "${DE}" == "lxqt" ]];  then
		ISONAME="Avouch-Live-Lxqt-0.2.0-x86_64"
		ISOLABEL="Avouch-Live"
		message "Live OS based on Lxqt will be created"
	else
		error "Please provide one of the gnome, plasma, xfce, lXqt as Desktop Environment"
		exit 1
	fi
else
	error "Please provide Desktop Environment"
	exit 1
fi

SRCDIR="/run/media/avouch/Avouch/Avouch/avh02/packages/x86_64"
INSTFILESDIR="/run/media/avouch/Avouch/Avouch/avh02/groups/dist/${DE}"

message "Detected install files directoy is : ${INSTFILESDIR}"

PKGFILES=( $( find ${INSTFILESDIR}/*.install -type f -print ))

make_live_img(){

	# make necessary directorys
	if [ ! -d ${WORK} ]; then
		mkdir -p ${WORK}/{${FSIMAGENAME},squashfs/LiveOS}
	else
		rm -r ${WORK}
		mkdir -p ${WORK}/{${FSIMAGENAME},squashfs/LiveOS}	
	fi
	
	if [ ! -d ${LIVECD} ]; then
		#mkdir -p ${LIVECD}/{LiveOS,boot/{grub,syslinux}}
		mkdir -p ${LIVECD}/{LiveOS,boot/grub,efi/boot}		
	else
		rm -r ${LIVECD}
		#mkdir -p ${LIVECD}/{LiveOS,boot/{grub,syslinux}}
		mkdir -p ${LIVECD}/{LiveOS,boot/grub,efi/boot}
	fi

	if [ ! -d ${ISODIR} ]; then
		mkdir -p ${ISODIR}		
	else
		rm -r ${ISODIR}
		mkdir -p ${ISODIR}
	fi

	# make image with truncate
	message "Creating live drive of ${DRIVE_SIZE} MB with dd utility ...."
	# truncate -s 10G "${DRIVE}"
	dd if=/dev/zero of="${DRIVE}" bs=1M count=${DRIVE_SIZE}

	
	# First unmount the partition
	if grep -qs ${DRIVE} /proc/mounts; then
  		message "Filesystem is mounted."
		umount -fd ${DRIVE} || exit 1
	else
  		message "Filesystem is not mounted."
	fi
	
	# format partition
	echo "Installing ${FILESYSTEM} filesystem on ${1}"
	# force to format with btrfs
	if [ ${FILESYSTEM} = "btrfs" ]; then
		mkfs.${FILESYSTEM} -L live ${DRIVE} || exit 1
	elif [ ${FILESYSTEM} = "ext3" ]; then
		mkfs.${FILESYSTEM} ${DRIVE} || exit 1
		tune2fs -c 0 -i 0 ${DRIVE} &> /dev/null
	elif [ ${FILESYSTEM} = "ext4" ]; then
		mkfs.${FILESYSTEM} ${DRIVE} || exit 1
		tune2fs -c 0 -i 0 ${DRIVE} &> /dev/null
	fi

}

mount_volume () {
	# mount image to mount point
	mount -o loop -t ${FILESYSTEM} ${DRIVE} ${MOUNTPOINT} || exit 1
	if [ -d "$MOUNTPOINT/var/avouch/log" ]; then
		rm -r "$MOUNTPOINT/var/avouch/log"
	else
		mkdir -p "$MOUNTPOINT/var/avouch/log"
		touch "$MOUNTPOINT/var/avouch/log/avouch-installl.log"
	fi
}

chroot_mount(){

	[ -e "${MOUNTPOINT}/sys" ] || mkdir "${MOUNTPOINT}/sys"
	[ -e "${MOUNTPOINT}/proc" ] || mkdir "${MOUNTPOINT}/proc"
	[ -e "${MOUNTPOINT}/dev" ] || mkdir "${MOUNTPOINT}/dev"
	mount -t sysfs sysfs "${MOUNTPOINT}/sys"
	mount -t proc proc "${MOUNTPOINT}/proc"
	mount -o bind /dev "${MOUNTPOINT}/dev"

}

# umount_volume()
# unmount the mount point and slected partition
#
umount_volume(){
	umount $MOUNTPOINT/proc
	umount $MOUNTPOINT/sys
	umount $MOUNTPOINT/dev

	losetup -d /dev/loop0
	umount -l $MOUNTPOINT
}

packages_to_install () {

# find total number of files in an array
message "Total files in array : ${#PKGFILES[*]}"

	for SRCFILES in "${PKGFILES[@]}"
		do  	
			# display the file to be installed
			echo "$SRCFILES"
			# check the file and call the install package function
			if [ -f "${SRCFILES}" ]; then
				# install the packages
				install_packages
				success "Package file ${SRCFILES} installed."
					
			else
				warning "Packages files ${SRCFILES} not found" red
				exit 1
			fi
		done
			
}

install_packages () {
	
	for FILES in $(grep -v '^#' "${SRCFILES}")
		do  	
		if [ -f "${SRCFILES}" ]; then	
			bsdtar -xf "$SRCDIR/${FILES}"	-C "${MOUNTPOINT}"
			message "Package ${FILES} installed sucessfully"
		else
			warning "Packages files ${FILES} not found" red
			exit 1
		fi	

    #log the entire loop
    done 2>&1 | tee -a "$MOUNTPOINT/var/avouch/log/avouch-installl.log" 

}

cleanup() {
	# remove static libraries
	message "Cleaning up static libraries"
	find "${MOUNTPOINT}/usr/lib/"*.a \
		-not -name "libc.a" \
		-not -name "libc_nonshared.a" \
		-not -name "libdl.a" \
		-not -name "libm.a" \
		-not -name "libpthread.a" \
		-type f -delete
	
	# remove rarely used documentation
	message "Cleaning up rarely used docs"

    rm -f ${MOUNTPOINT}/usr/share/doc/valgrind/valgrind_manual.ps
    rm -f ${MOUNTPOINT}/usr/share/doc/sudo/ChangeLog
    
    rm -f ${MOUNTPOINT}/usr/share/fonts/TTF/Jameel_Noori_Nastaleeq.ttf
    rm -f ${MOUNTPOINT}/usr/share/fonts/TTF/Jameel_Noori_Nastaleeq_Kasheeda.ttf
    
    find "${MOUNTPOINT}/usr/share/doc" -name "*.html" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.css" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.js" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.c" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.gif" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.jpg" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.png" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.ps" -type f -delete
    find "${MOUNTPOINT}/usr/share/doc" -name "*.pdf" -type f -delete
    
    # delete all examples directories
    find "${MOUNTPOINT}/usr/share/doc" -name "example" -type d -print0 | xargs -0 /usr/bin/rm -rf
    find "${MOUNTPOINT}/usr/share/doc" -name "examples" -type d -print0 | xargs -0 /usr/bin/rm -rf

	# delete fltk games and fluid
	rm ${MOUNTPOINT}/usr/bin/{blocks,checkers,fluid,sudoku}
	rm ${MOUNTPOINT}/usr/share/applications/{blocks.desktop,checkers.desktop,fluid.desktop,sudoku.desktop}

	# delete avahi apps .desktop files
	rm ${MOUNTPOINT}/usr/share/applications/{avahi-discover.desktop,bssh.desktop,bvnc.desktop}

	# delete alsa tools .desktop files
	rm ${MOUNTPOINT}/usr/share/applications/{echomixer.desktop,envy24control.desktop,hdspconf.desktop,hdspmixer.desktop,hwmixvolume.desktop}

	# delete xterm .desktop files
	rm ${MOUNTPOINT}/usr/share/applications/{uxterm.desktop,xterm.desktop}
    
    # delete all empty directories
    find  "${MOUNTPOINT}/usr/share/doc"  -type d -empty -delete

	if [[ "${DE}" == "gnome" ]]; then
		# delete some gnome wallpaper to save space
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Blobs.svg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/BrushStrokes.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/ColdWarm.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Disco.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/DiscoHex.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Frosty.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Leaf.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/LightBulb.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Loveles.jpg"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Symbolics-1.png"
		rm -r "${MOUNTPOINT}/usr/share/backgrounds/gnome/Wood.jpg"
		# delete some plasma wallpaper to save space
		# rm -r "${MOUNTPOINT}/usr/share/wallpapers/Next"
	elif [[ "${DE}" == "plasma" ]]; then
		# delete some plasma wallpaper to save space
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/Autumn"
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/ColorfulCups"
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/EveningGlow"
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/FlyingKonqui"
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/Kite"
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/OneStandsOut"
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/Path"
	elif [[ "${DE}" == "lxqt" ]]; then
		# delete some plasma wallpaper to save space
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/Next"
	elif [[ "${DE}" == "xfce" ]]; then
		# delete some plasma wallpaper to save space
		rm -r "${MOUNTPOINT}/usr/share/wallpapers/Next"
	fi

	# delete gtk-docs
	message "Cleaning up rarely used gtk-docs"
	echo "Cleaning up rarely used gtk-docs"
    rm -rf  "${MOUNTPOINT}/usr/share/gtk-doc/html/"*

	# v4l-utils extras
	rm -f "${MOUNTPOINT}/usr/share/applications/qvidcap.desktop"
	rm -f "${MOUNTPOINT}/usr/share/applications/qv4l2.desktop"
	rm -f "${MOUNTPOINT}/usr/share/applications/lstopo.desktop"

	# message "Cleaning locale directory"
	# find "${MOUNTPOINT}/usr/share/locale/" -type d -print0 | xargs -0 rm -rf

}


fstab_setup(){
# fstab
cat > ${MOUNTPOINT}/etc/fstab << "EOF"
/dev/root  /         btrfs    defaults,noatime 0 0
devpts     /dev/pts  devpts  gid=5,mode=620   0 0
tmpfs      /dev/shm  tmpfs   defaults         0 0
proc       /proc     proc    defaults         0 0
sysfs      /sys      sysfs   defaults         0 0
EOF

}

genrate_locale() {
	message "Generating locales"
	sed -i 's/#ar_EG.UTF-8/ar_EG.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#de_DE.UTF-8/de_DE.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#en_US ISO-8859-1/en_US ISO-8859-1/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#es_ES.UTF-8/es_ES.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#fr_FR.UTF-8/fr_FR.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#ja_JP.UTF-8/ja_JP.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen
	sed -i 's/#zh_CN.UTF-8/zh_CN.UTF-8/g' ${MOUNTPOINT}/etc/locale.gen

	chroot ${CHROOTDIR} usr/bin/locale-gen
	
	ln -sfv ../usr/share/zoneinfo/UTC ${MOUNTPOINT}/etc/localtime 

	# remove resolv.conf file
	if [ -f ${MOUNTPOINT}/etc/resolv.conf ];then
		rm ${MOUNTPOINT}/etc/resolv.conf 
	fi
		# remove hostname file
	if [ -f ${MOUNTPOINT}/etc/hostname ];then
		rm ${MOUNTPOINT}/etc/hostname
	fi
	echo "avouchlive" > ${MOUNTPOINT}/etc/hostname

	# ca-certificates
	message "$(gettext "Updating ca-certificates...")"	
	# export LC_ALL=C
	chroot ${CHROOTDIR} usr/bin/update-ca-trust

	# generate key
	chroot ${CHROOTDIR} unbound-anchor -a "etc/trusted-key.key"
	message "ca-certificates updated"

	# touch ${MOUNTPOINT}/etc/passwd-
	chroot ${CHROOTDIR} touch /etc/gshadow-
	chroot ${CHROOTDIR} touch /etc/passwd-
	chroot ${CHROOTDIR} touch /etc/shadow-
	chroot ${CHROOTDIR} grpck
	chroot ${CHROOTDIR} pwconv
	chroot ${CHROOTDIR} grpconv

	# grafivize fix for unrecognize file formats.
	# Format: "png" not recognized. No formats found.
	# Perhaps "dot -c" needs to be run (with installer's privileges) to register the plugins?
	chroot ${CHROOTDIR} dot -c
}


add_users(){
	# enable services by systemctl preset
	message "Adding systemd users"
	chroot ${CHROOTDIR} systemd-sysusers

	# copy default configuration files to skel directory
	cp -r "${BASEDIR}"/liveuser/.config "${MOUNTPOINT}/etc/skel/"
	cp -r "${BASEDIR}"/liveuser/.gtkrc-2.0 "${MOUNTPOINT}/etc/skel/"

	message "Adding user ${USERNAME} "
	chroot ${CHROOTDIR} useradd -c "Live User" -m "${USERNAME}" -s /bin/bash
	chroot ${CHROOTDIR} usermod -a -G wheel ${USERNAME}

	chroot ${CHROOTDIR} passwd -d ${USERNAME} > /dev/null
	message "password for ${USERNAME} set to blank"

	# give default user sudo privileges
	echo "%wheel     ALL=(ALL)     NOPASSWD: ALL" >> "${MOUNTPOINT}/etc/sudoers"

	# Remove root password lock
	chroot ${CHROOTDIR} passwd -d root > /dev/null
	message "password for root set to blank"

	# workaround for restorecond warning
	chroot ${CHROOTDIR} mkdir -p /root/.ssh
	# incase of failure
	chroot ${CHROOTDIR} touch /root/.Xauthority
	chroot ${CHROOTDIR} touch /home/${USERNAME}/.Xauthority	
	chroot ${CHROOTDIR} chown ${USERNAME}:${USERNAME}  /home/${USERNAME}/.Xauthority
}

systemd_setup() {
	message "Generating systemd machine id"
	chroot ${CHROOTDIR} systemd-machine-id-setup

	# creat dbus link to machine-id, so that both dbus and systemd uses same machine-id
	chroot ${CHROOTDIR} mkdir -p "/var/lib/dbus"
	chroot ${CHROOTDIR} ln -sf /etc/machine-id "$pkgdir"/var/lib/dbus

	message "updating journalctl cataloge"
	chroot ${CHROOTDIR} usr/lib/systemd/systemd-random-seed save
	chroot ${CHROOTDIR} journalctl --update-catalog
	
	#echo "creating systemd-sysuser"
	#chroot ${CHROOTDIR} systemd-sysusers
	
	message "creating systemd-tmpfiles"
	chroot ${CHROOTDIR} systemd-tmpfiles --create

	# Apply ACL to the journal directory
	chroot ${CHROOTDIR} setfacl -Rnm g:wheel:rx,d:g:wheel:rx,g:adm:rx,d:g:adm:rx /var/log/journal/

	# enable services by systemctl preset
	message "Generating systemd preset"
	chroot ${CHROOTDIR} systemctl preset \
			remote-fs.target \
			getty@.service \
			serial-getty@.service \
			console-getty.service \
			debug-shell.service \
			systemd-homed.service \
			systemd-timesyncd.service \
			systemd-networkd.service \
			systemd-networkd-wait-online.service \
			systemd-resolved.service \
			lvm2-monitor.service \
			avahi-daemon.service \
			bluetooth.service \
			ModemManager.service \
			NetworkManager.service \
			restorecond.service \
			acpid.service
	
	if [[ "${DE}" == "gnome" ]]; then
		chroot ${CHROOTDIR} systemctl enable gdm.service			     
        chroot ${CHROOTDIR} setcap 'cap_sys_nice+ep' /usr/bin/mutter	
		chroot ${CHROOTDIR} setcap 'cap_sys_nice+ep' /usr/bin/gnome-shell
		chroot ${CHROOTDIR} setcap 'cap_net_bind_service=+ep' /usr/lib/gvfsd-nfs
		chroot ${CHROOTDIR} setcap 'cap_ipc_lock=ep' /usr/bin/gnome-keyring-daemon
		
	elif [[ "${DE}" == "plasma" ]]; then
		chroot ${CHROOTDIR} systemctl enable sddm.service			
        # chroot ${CHROOTDIR} setcap 'cap_net_bind_service=+ep' /usr/lib/gvfsd-nfs
        # chroot ${CHROOTDIR} setcap 'cap_ipc_lock=ep' /usr/bin/gnome-keyring-daemon
		chroot ${CHROOTDIR} setcap 'CAP_SYS_NICE=+ep' /usr/bin/kwin_wayland
		chroot ${CHROOTDIR} setcap 'CAP_NET_RAW=+ep' /usr/lib/ksysguard/ksgrd_network_helper

	elif [[ "${DE}" == "lxqt" ]]; then
		chroot ${CHROOTDIR} systemctl enable sddm.service			
        chroot ${CHROOTDIR} setcap 'cap_net_bind_service=+ep' /usr/lib/gvfsd-nfs
        chroot ${CHROOTDIR} setcap 'cap_ipc_lock=ep' /usr/bin/gnome-keyring-daemon
		chroot ${CHROOTDIR} setcap 'CAP_SYS_NICE=+ep' /usr/bin/kwin_wayland

	elif [[ "${DE}" == "xfce" ]]; then
		chroot ${CHROOTDIR} systemctl enable sddm.service			
        chroot ${CHROOTDIR} setcap 'cap_net_bind_service=+ep' /usr/lib/gvfsd-nfs
        chroot ${CHROOTDIR} setcap 'cap_ipc_lock=ep' /usr/bin/gnome-keyring-daemon
		# chroot ${CHROOTDIR} setcap 'CAP_SYS_NICE=+ep' /usr/bin/kwin_wayland
	fi

	# Enable xdg-user-dirs-update by default
	chroot ${CHROOTDIR} systemctl --global enable xdg-user-dirs-update.service
	chroot ${CHROOTDIR} systemctl --global enable pulseaudio.socket

	# Enable socket by default
	chroot ${CHROOTDIR} systemctl --global enable p11-kit-server.socket
	chroot ${CHROOTDIR} systemctl --global enable pipewire.socket

	# update udev dtabase
	chroot ${CHROOTDIR} udevadm hwdb --update

	# enable swapfc for on demand swap space
	sed -i 's/#swapfc_enabled=0/swapfc_enabled=1/g' ${MOUNTPOINT}/etc/systemd/swap.conf

	# Prevent some services to be started in the livecd
	echo 'File created by alim. See systemd-update-done.service(8).' \
		| tee "${MOUNTPOINT}/etc/.updated" >"${MOUNTPOINT}/var/.updated"
}

generate_cache(){
	message "$(gettext "Generating ldconfig cache...")"	
	chroot ${CHROOTDIR} ldconfig

	# fonts cache
	message "$(gettext "Generating fonts cache...")"	
	chroot ${CHROOTDIR} fc-cache -f
	chroot ${CHROOTDIR} mkfontdir /usr/share/fonts/*

	# gdk-pixbuf update cache
	message "$(gettext "Generating gdk-pixbuf cache...")"	
	chroot ${CHROOTDIR} gdk-pixbuf-query-loaders --update-cache

	# gtk cache
	message "$(gettext "Generating gtk2 cache...")"	
	chroot ${CHROOTDIR} gtk-query-immodules-2.0 --update-cache

	# gtk3 cache
	message "$(gettext "Generating gtk3 cache...")"	
	chroot ${CHROOTDIR} gtk-query-immodules-3.0 --update-cache

	# glib compile schema
	message "$(gettext "Compiling glib schemas...")"	
	chroot ${CHROOTDIR} glib-compile-schemas usr/share/glib-2.0/schemas

	# icon cache
	message "$(gettext "Generating icone cache...")"	
	chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/Avouch
	chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/hicolor
	chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/locolor

	if [[ "${DE}" == "gnome" ]]; then
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/Adwaita
		chroot ${CHROOTDIR} dconf update
	elif [[ "${DE}" == "plama" ]]; then
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/breeze
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/breeze-dark
	elif [[ "${DE}" == "lxqt" ]]; then
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/breeze
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/breeze-dark
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/oxygen
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/nuoveXT2
	elif [[ "${DE}" == "xfce" ]]; then
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/Adwaita
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/breeze
		chroot ${CHROOTDIR} gtk-update-icon-cache -q -t -f usr/share/icons/breeze-dark
	fi

	chroot ${CHROOTDIR} xdg-icon-resource forceupdate --theme hicolor
	# vlc cache-gen
	if [ -f ${MOUNTPOINT}/usr/lib/vlc/vlc-cache-gen ]; then
		message "$(gettext "Generating vlc cache...")"	
		chroot ${CHROOTDIR} usr/lib/vlc/vlc-cache-gen usr/lib/vlc/plugins
	fi

	# mime database
	message "$(gettext "Updating mime-database...")"	
	chroot ${CHROOTDIR} update-mime-database usr/share/mime

	# desktop database
	message "$(gettext "Updating desktop-database...")"	
	chroot ${CHROOTDIR} update-desktop-database -q

	# man-db database
	message "$(gettext "Updating man-db database...")"	
	#/usr/bin/mandb --quiet
}

final_config() {

# install info
pushd ${MOUNTPOINT}/usr/share/info
	for f in *
	  do install-info $f dir 2>/dev/null
	done
popd

# as gnome-terminal does not support utf language.
cat > ${MOUNTPOINT}/etc/locale.conf << "EOF"
LANG=en_US.UTF-8
EOF

# set plymouth theme to avouch
sed -i "s/spinner/avouch/g" ${MOUNTPOINT}/etc/plymouth/plymouthd.conf

if [[ "${DE}" == "gnome" ]]; then
	# enable gdm-initial-setup
	if [ -f ${MOUNTPOINT}/etc/gdm/custom.conf ]; then
		mv ${MOUNTPOINT}/etc/gdm/custom.conf ${MOUNTPOINT}/etc/gdm/custom.conf.orig
	fi

	cat > ${MOUNTPOINT}/etc/gdm/custom.conf << "EOF"
[daemon]
# WaylandEnable=false
AutomaticLoginEnable=True
AutomaticLogin=liveuser
XSession=gnome
EOF
	# disable gnome-initial-setup
	# mkdir -p ${MOUNTPOINT}/home/${USERNAME}/.config
	cat > ${MOUNTPOINT}/home/${USERNAME}/.config/gnome-initial-setup-done << "EOF"
yes
EOF
	chroot ${CHROOTDIR} chown "${USERNAME}:${USERNAME}" "home/${USERNAME}/.config/gnome-initial-setup-done"

	# remove unnecessary xsession desktop files
	# rm "${MOUNTPOINT}/usr/share/xsessions/gnome-flashback-compiz.desktop"
	# rm "${MOUNTPOINT}/usr/share/xsessions/gnome-flashback-metacity.desktop"
	# rm "${MOUNTPOINT}/usr/share/xsessions/gnome.desktop"
	rm "${MOUNTPOINT}/usr/share/wayland-sessions/weston.desktop"

elif [[ "${DE}" == "plasma" ]]; then
	# backup sddm config file
	if [ -f ${MOUNTPOINT}/etc/sddm.conf ]; then
		mv ${MOUNTPOINT}/etc/sddm.conf ${MOUNTPOINT}/etc/sddm.conf.orig
	fi

# sddm autologin
# kwin require opengl minimum 2.1, set it to use xrender
# so that older computers are able to logon to plasma

	cat > ${MOUNTPOINT}/etc/sddm.conf << "EOF"
[Autologin]
Session=plasma.desktop
User=liveuser

[General]
Numlock=on

[Theme]
Current=breeze
CursorTheme=breeze
EOF

	# remove unnecessary xsession desktop files
	# rm "${MOUNTPOINT}/usr/share/xsessions/openbox-kde.desktop"
	# rm "${MOUNTPOINT}/usr/share/xsessions/openbox.desktop"
	rm "${MOUNTPOINT}/usr/share/xsessions/plasma-mediacenter.desktop"
	rm "${MOUNTPOINT}/usr/share/wayland-sessions/weston.desktop"
	
elif [[ "${DE}" == "lxqt" ]]; then
	# backup sddm config file
	if [ -f ${MOUNTPOINT}/etc/sddm.conf ]; then
		mv ${MOUNTPOINT}/etc/sddm.conf ${MOUNTPOINT}/etc/sddm.conf.orig
	fi

# sddm autologin
# kwin require opengl minimum 2.1, set it to use xrender
# so that older computers are able to logon to lxqt

	cat > ${MOUNTPOINT}/etc/sddm.conf << "EOF"
[Autologin]
Session=lxqt.desktop
User=liveuser

[General]
Numlock=on

[Theme]
Current=chili
CursorTheme=
EOF

	rm "${MOUNTPOINT}/usr/share/wayland-sessions/weston.desktop"
elif [[ "${DE}" == "xfce" ]]; then
	# backup sddm config file
	if [ -f ${MOUNTPOINT}/etc/sddm.conf ]; then
		mv ${MOUNTPOINT}/etc/sddm.conf ${MOUNTPOINT}/etc/sddm.conf.orig
	fi

# sddm autologin
# kwin require opengl minimum 2.1, set it to use xrender
# so that older computers are able to logon to lxqt

	cat > ${MOUNTPOINT}/etc/sddm.conf << "EOF"
[Autologin]
Session=xfce.desktop
User=liveuser

[General]
Numlock=on

[Theme]
Current=chili
CursorTheme=
EOF

	rm "${MOUNTPOINT}/usr/share/wayland-sessions/weston.desktop"
fi

	# fix for polkit until all packagesare updates for polkiy group 70
	chown 70:0 "${MOUNTPOINT}/etc/polkit-1/rules.d"
	chown 70:0 "${MOUNTPOINT}/usr/share/polkit-1/rules.d"

	chmod 700 "${MOUNTPOINT}/etc/polkit-1/rules.d"
	chmod 700 "${MOUNTPOINT}/usr/share/polkit-1/rules.d"

	#Lynis ??? Warning: Incorrect permissions for file /root/.ssh [test:FILE-7524]
	chmod 700 "${MOUNTPOINT}/root/.ssh"

	# The database required for 'locate' could not be found. 
	# Run 'updatedb' or 'locate.updatedb' to create this file. [FILE-6410]
	chroot ${CHROOTDIR} updatedb


	# Avouch version
	echo "${AVH_REL_STRING}" >> ${MOUNTPOINT}/etc/avouch-release

	# enable SELinux
	if [ -e "${MOUNTPOINT}/etc/selinux/config" ]
	then
		message ">>> In order to use this policy, set SELINUXTYPE=refpolicy in /etc/selinux/config."
	else
		chroot ${CHROOTDIR} ln -sv config.refpolicy "etc/selinux/config"
	fi

	message ">>> Building refpolicy policy store. Please wait..."
	chroot ${CHROOTDIR} semodule -s refpolicy -i "/usr/share/selinux/refpolicy/"*.pp
	message ">>> Relabeling the filesystem..."
	chroot ${CHROOTDIR} restorecon -rF /
	message ">>> This can be done with: /usr/bin/restorecon -rF /"

	message "Fixing the ownership for usr ${USERNAME} "
	# incase of failure
	# chroot ${CHROOTDIR} touch /root/.Xauthority
	# chroot ${CHROOTDIR} touch /home/${USERNAME}/.Xauthority
	# chroot ${CHROOTDIR} chown "${USERNAME}:${USERNAME}"  /home/${USERNAME}/.Xauthority

	chroot ${CHROOTDIR} chmod 755 "home/${USERNAME}"
	# chroot ${CHROOTDIR} chown "${USERNAME}:${USERNAME}" /home/"${USERNAME}"
	# chroot ${CHROOTDIR} chown -Rf "${USERNAME}:${USERNAME}" /home/${USERNAME}/*

	# workaround for restorecond warning
	chroot ${CHROOTDIR} mkdir -p /root/.ssh

	# chnage default #DefaultTimeoutStopSec=90s
	sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=20s/g' "${MOUNTPOINT}/etc/systemd/system.conf"

	# temporary fix
	rm ${MOUNTPOINT}/usr/share/applications/selinux-polgengui.desktop
	rm ${MOUNTPOINT}/usr/share/applications/sepolicy.desktop

}

make_initramfs(){
	local KERNVER=$(<${MOUNTPOINT}/usr/src/linux/version)
	message "Generating initramfs.img"
	cp -f "${DATADIR}"/04-livecd.conf "${MOUNTPOINT}/etc/dracut.conf.d"

	chroot ${CHROOTDIR} depmod -a ${KERNVER}
	chroot ${CHROOTDIR} dracut '/boot/initramfs.img' ${KERNVER} --zstd --force --verbose

	# remove dracut 04-livecd.conf
	rm -f ${MOUNTPOINT}/etc/dracut.conf.d/04-livecd.conf

	message "Done Generating initramfs.img."
}

make_squashfs(){

	local KERNVER=$(<${MOUNTPOINT}/usr/src/linux/version)
	ln -svf ../usr/lib/modules/${KERNVER}/vmlinuz ${MOUNTPOINT}/boot/vmlinuz-${KERNVER}
	cp -vp ${MOUNTPOINT}/usr/lib/modules/${KERNVER}/vmlinuz ${LIVECD}/boot/vmlinuz
	cp -vp ${MOUNTPOINT}/boot/initramfs.img ${LIVECD}/boot/initramfs.img
	cp -vp ${MOUNTPOINT}/boot/memtest86+/memtest.bin ${LIVECD}/boot/memtest
	cp -vp ${MOUNTPOINT}/boot/intel-ucode.img ${LIVECD}/boot/intel-ucode.img


	# remove initramfs from image
	rm ${WORK}/${FSIMAGENAME}/boot/initramfs.img

	chmod 644 ${LIVECD}/boot/vmlinuz
	chmod 644 ${LIVECD}/boot/initramfs.img
	chmod 644 ${LIVECD}/boot/intel-ucode.img

	# unmount chroot first
	umount_volume
		
	# make squashfs
	message "Making squash file system of ${FSIMAGENAME}.img"
	mksquashfs ${WORK}/squashfs/LiveOS ${LIVECD}/LiveOS/squashfs.img -b 1M -comp zstd -keep-as-directory

	success "Done building squashfs with xz compression."

	message "Creating checksum file for self-test..."
	pushd "${LIVECD}/LiveOS"
		sha256sum squashfs.img > ${LIVECD}/LiveOS/squashfs.sha
	popd

}

boot_config(){
	cp "${DATADIR}/grub.cfg"  "${LIVECD}/boot/grub/grub.cfg"
	# cp "${DATADIR}/bootx64.efi"  "${LIVECD}/efi/boot/bootx64.efi"

	grub-mkstandalone \
		--format 'x86_64-efi' \
		--output="${LIVECD}/efi/boot/bootx64.efi" \
		--locales="" \
		--fonts="" \
		--themes=avouch \
		"boot/grub/grub.cfg=boot/grub/grub.cfg"
	
	#message "Adding UEFI support ..."
	#pushd ${LIVECD}/efi/boot		
		# Format the image as FAT12:
		#mkdosfs -F 12 efi.img
		#mformat -C -f 2880 -L 16 -i efi.img
		
		# Create a temporary mount point:
		#local EFIMOUNTPOINT=$(mktemp -d)
		
		# Mount the image there:
		#mount -t vfat -o loop efi.img "${EFIMOUNTPOINT}"
		
		# Copy the GRUB binary to /EFI/BOOT:
		#mkdir -p $EFIMOUNTPOINT/efi/boot
		#cp -a bootx64.efi $EFIMOUNTPOINT/efi/boot/bootx64.efi
		#cp -a grub.cfg $EFIMOUNTPOINT/efi/boot/grub.cfg

		# Unmount and clean up:
		#umount -l "${EFIMOUNTPOINT}"
		#rmdir "${EFIMOUNTPOINT}"

		# Move the efiboot.img to ${LIVECD}/isolinux:
		#mv efi.img ${LIVECD}/boot/efi.img

	#popd
}

# Create an ISO9660 filesystem from "iso" directory.
make_iso () {
	pushd "${BASEDIR}"
		grub-mkrescue \
			--themes="avouch" \
			--product-name="${ISOLABEL}" \
			--product-version='0.2.0' \
			-volid "${ISOLABEL}" \
			-o "${ISODIR}/${ISONAME}.iso" "${LIVECD}"
		
		success "ISO with EFI support generated successfully."
	popd

	pushd "${ISODIR}"
		message "Creating checksum (sha256sum) file for iso ..."
		sha256sum "${ISONAME}.iso"  > "${ISONAME}.sha"
	popd

	chmod 1777 "${ISODIR}/${ISONAME}.iso"
	success "Avouch Live image created successfully."
}

main() {   
    check_root
    make_live_img
    mount_volume
    packages_to_install    
    fstab_setup
    chroot_mount
	cleanup
    genrate_locale
    add_users
    systemd_setup
    generate_cache
    final_config
    make_initramfs    
    make_squashfs
	boot_config
    make_iso
}
main "$@"
