@echo off
nasm -f bin kernel.asm -o BOOTX64.efi
nasm -f bin helper.asm -o turtle.efi
xcopy /y BOOTX64.efi "Drive\EFI\BOOT"
xcopy /y turtle.efi "Drive\EFI"
choice /n /m "Should we copy the image to a USB drive? [Y/N]:"
PAUSE
if %errorlevel%==1 (
	:: Thanks to @Magoo for getting string user input in a batch script: https://stackoverflow.com/questions/65568800/how-do-i-take-a-user-input-in-bat-script
	set /p "driveName=Specify the label name of the USB (e.g. "USB DRIVE"):"

	:: Thanks to @dbenham for how to reference a USB from its volume name: https://stackoverflow.com/questions/9065280/reference-a-volume-drive-by-label
	for /f %%D in ('wmic volume get DriveLetter^, Label ^| find "%driveName%"') do set "drive=%%D"
	echo Drive %driveName% is at %drive%
	
	xcopy /y /s "Drive\" "%drive%\"
	echo USB writing done!
)

choice /n /m "Should we run the image in QEMU? [Y/N]:"
PAUSE
if %errorlevel%==1 (
	"C:\Program Files\qemu\qemu-system-x86_64.exe" -pflash OVMF.fd -net none -drive file=fat:rw:Drive,format=raw
)

echo All done!
PAUSE
