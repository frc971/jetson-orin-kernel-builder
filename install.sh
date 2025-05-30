# Prerequisites
# Jetpack 6.1 Orin
# (Optional) To build faster set the powermode to max by clicking on the nvidia icon on the top right and setting powermode to MAXN (This will require a reboot)

git clone https://github.com/charliehuang09/jetson-orin-kernel-builder
cd jetson-orin-kernel-builder
cd scripts
sudo ./get_kernel_sources.sh
sudo ./edit_config_cli.sh -d /home/nvidia/l4t/r36.4.0
sudo ./make_kernel.sh -d /home/nvidia/l4t/r36.4.0
sudo ./make_kernel_modules.sh -d /home/nvidia/l4t/r36.4.0

cd /home/nvidia/l4t/r36.4.0

sudo cp /home/nvidia/Documents/jetson-orin-kernel-builder/patches/tegra234-p3767-camera-p3768-imx477-imx296.dts hardware/nvidia/t23x/nv-public/overlay/
sudo cp /home/nvidia/Documents/jetson-orin-kernel-builder/patches/tegra234-p3767-camera-p3768-imx219-imx296.dts hardware/nvidia/t23x/nv-public/overlay/
sudo cp /home/nvidia/Documents/jetson-orin-kernel-builder/patches/tegra234-p3767-camera-p3768-imx296-imx296.dts hardware/nvidia/t23x/nv-public/overlay/
sudo cp /home/nvidia/Documents/jetson-orin-kernel-builder/patches/overlay/Makefile hardware/nvidia/t23x/nv-public/overlay/

sudo cp /home/nvidia/Documents/jetson-orin-kernel-builder/patches/imx296* nvidia-oot/drivers/media/i2c/
sudo cp /home/nvidia/Documents/jetson-orin-kernel-builder/patches/i2c/Makefile nvidia-oot/drivers/media/i2c/

sudo chown -R nvidia:nvidia .
make -j5 modules
make -j5 dtbs

sudo mv /boot/Image /boot/Image.backup
sudo cp kernel/kernel-jammy-src/arch/arm64/boot/Image /boot/Image
sudo cp kernel-devicetree/generic-dts/dtbs/tegra234-p3767-camera-p3768-imx477-imx296.dtbo /boot/

cd /opt/nvidia/jetson-io
sudo ./jetson-io.py

# What to do after:
# Edit extlinux.conf to have the imx296 overlay (see example/extlinux.conf) and set up the backup image
# Reboot
# sudo insmod l4t/r36.4.0/nvidia-oot/drivers/media/i2c/imx296.ko
# Test with
# gst-launch-1.0 nvarguscamerasrc sensor-id=0  aelock=true exposuretimerange="100000 200000"  gainrange="1 15"  ispdigitalgainrange="1 1" ! 'video/x-raw(memory:NVMM), width=(int)1456, height=(int)1088, framerate=(fraction)60/1, format=(string)NV12' ! nveglglessink -e
