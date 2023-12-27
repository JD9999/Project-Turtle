# What is Project Turtle?
Project Turtle is a UEFI application written in NASM assembly for x86 (e.g. Intel and AMD) computers.

## What is the goal?
The goal is to create a UEFI application to read images off a drive and display them on a screen, like an electronic advertising sign.
However, using this program would bypass an operating system entirely, completely removing lots of the complexity and possible issues that could come from underlying software (e.g. Windows).
It would also make for an extremely light-weight purpose-built system.

## How close is it to the goal?
Not very far. The current progress is that the application can print strings and numbers, get information about itself (EFI LOADED IMAGE) and can use the device path utilities protocol to get the size of the device path of the loaded image.

The next step is to get it to be able to load and start the second EFI file from the first. This will enable the application to be modular (and therefore, relatively easier to navigate and develop with)

# How do I setup Project Turtle?
There are multiple options for you:
1. Extract the release ZIP file to the root of your USB
2. Download the source code and use the buildAndRunFull script to run it on QEMU
3. Download the source code and use the buildAndRunFull script to copy it to your USB

## 1. Extract the release ZIP file
Don't want any hassle with code or scripts? No problem! Follow these steps to try it out for yourself, no coding required!
1. Download the latest [release](https://github.com/JD9999/Project-Turtle/releases)
2. Extract the contents of the ZIP file to the root directory of your USB (e.g. D:/)
3. If the "EFI" folder is in a directory like "D:/Project-Turtle-A0.0.1_Release", change it so that the "EFI" folder is in the root directory

## 2. Run it on QEMU
Before starting this process, make sure that you have [the NASM compiler](nasm.us) and the [QEMU](www.qemu.org) virtual machine installed on your machine
Use the buildAndRunFull script to run it on QEMU:
1. Download the source code (git clone https://github.com/JD9999/Project-Turtle)
2. Run the buildAndRunFull script (.bat for Windows, .sh for Linux)
3. When asked about copying it to a USB, type "N" and press enter
4. When asked about running it on QEMU, type "Y" and press enter
5. A QEMU window will come up. When the 5 second timer starts, do not press escape. It will run automatically!

## 3. Copy it to a USB drive
Before starting this process, make sure that you have [the NASM compiler](nasm.us) installed on your machine
Use the buildAndRunFull script to copy it onto your USB drive:
1. Download the source code (git clone https://github.com/JD9999/Project-Turtle)
2. Run the buildAndRunFull script (.bat for Windows, .sh for Linux)
3. When asked about copying it to a USB, type "Y" and press enter
4. When prompted, enter the label of the USB drive. This is its name, not the drive name (e.g. "USB Drive", NOT "D:/")
5. When asked about running it on QEMU, type "N" and press enter

# How can I raise issues with Project Turtle?
You can add an issue in GitHub and I will look into it.

# How can I contribute to Project Turtle?
You can contribute by sending a Pull Request in GitHub.
I welcome all helpful contributions!

# Can I use your code in my project?
Absolutely! Please do!
Just remember to include the MIT license in your code if you use a substantial portion of this software in your project (per the license agreement).
