#!/bin/bash

# first build the bootloader
cd bootloader
./build_bootloader.sh
cd ..

# delete the elf to force a re-link (it might not pick up the bootloader otherwise)
rm -r build/
rm ../for_rusefi/wideband_image.h

make -j12

# Copy the bin without the bootloader (the image consumed by rusEfi has no bootloader on it)
dd if=build/wideband.bin of=build/wideband_noboot_no_pad.bin skip=6144 bs=1

# extend the image out to full size (32k (flash) - 6k (bootloader) - 1k (config) - 4 (crc) = 25k - 4 = 0x63FC)
arm-none-eabi-objcopy -I binary -O binary --gap-fill 0xFF --pad-to 0x63FC build/wideband_noboot_no_pad.bin build/wideband_fullsize_nocrc.bin

# compute the crc and write that to a file
crc32 build/wideband_fullsize_nocrc.bin | xxd -r -p - > build/wideband_crc.bin

# Now glue the image and CRC together
cat build/wideband_fullsize_nocrc.bin build/wideband_crc.bin > build/wideband_image.bin

# Convert to a header file, and tack "static const " on the front of it
xxd -i build/wideband_image.bin \
    | cat <(echo -n "static const ") - \
    > ../for_rusefi/wideband_image.h