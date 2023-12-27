#!/bin/sh

#Choose yes or no
choose_yn(){
	read response
	case $response in 
	"Y" | "y")
		return 0
		;;
	"N" | "n")
		return 1
		;;
	*)
		echo "Invalid input. Enter 'Y' or 'N'"
		return choose_yn
		;;
	esac
	
}

nasm -f bin kernel.asm -o BOOTX64.efi
nasm -f bin helper.asm -o turtle.efi
cp BOOTX64.efi Drive/EFI/BOOT/BOOTX64.efi
cp turtle.efi Drive/EFI/turtle.efi
cp startup.nsh Drive/EFI/BOOT/startup.nsh
echo "Should we copy the image to a USB drive? [Y/N]:"
choose_yn

tmp=$?
if [ $tmp -eq 0 ]
then
	echo "Specify the label name of the USB (e.g. \"USB DRIVE\"):"
	read usb_name
	username="$(logname)"
	usb_path="/media/${username}/${usb_name}"
	cp -r Drive/EFI $usb_path
	echo "USB writing done!"
fi

echo "Should we run the image in QEMU? [Y/N]:"
choose_yn

tmp=$?
if [ $tmp -eq 0 ]
then
	qemu-system-x86_64 -pflash OVMF.fd -net none -drive file=fat:rw:Drive,format=raw #Note: The OVMF package contains an OVMF.fd in /usr/share/ovmf
fi

echo "All done!"
