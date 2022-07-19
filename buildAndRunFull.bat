nasm -f bin kernal.asm -o BOOTX64.efi
del "Drive\EFI\BOOT\BOOTX64.efi"
xcopy /y BOOTX64.efi "Drive\EFI\BOOT"
echo "Ready to continue?"
PAUSE
"C:\Program Files (x86)\ImgBurn\ImgBurn.exe" /MODE BUILD /BUILDINPUTMODE STANDARD /BUILDOUTPUTMODE IMAGEFILE /SRC "Drive" /DEST UEFI.ISO /VOLUMELABEL "UEFI" /OVERWRITE YES /START /CLOSESUCCESS /NOIMAGEDETAILS /NOSAVESETTINGS /ROOTFOLDER YES
"C:\Program Files\qemu\qemu-system-x86_64.exe" -cdrom UEFI.ISO -cpu qemu64 -pflash OVMF.fd -L "C:\Program Files\qemu" -net none -monitor stdio
PAUSE
