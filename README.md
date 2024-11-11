# Intro

This guide is for setting up a wireless-usb connection between an ancient 3d printer and an SBC.  
In this setup, a NAS server was used as the instructing unit, that runs an octoprint instance and binds the usb device to the container. 
The acting unit (that controls the 3d printer) is a raspberry pi zero W, that is connected to the 3d printer per usb and shares that usb conenction over LAN.

In the end, the octoprint docker container serves the app and sends commands, the PI receives them and passes them to the 3d printer.
If fou whatever reason you also want this setup, follow along.

# Setup 

## 1. Set Up the Raspberry Pi as a USB/IP Server/actor

The Pi needs to have an sd card prepared (using e.g. pi imager). It needs to be connected to the printer via a physical USB cable and get `usbip` installed to share that connection to the network.

- Update the system and install USB/IP:
  ```bash
  sudo apt update
  sudo apt install -y usbip
  ```

- Load the necessary kernel modules:
  ```bash
  sudo modprobe usbip_host
  sudo modprobe vhci_hcd
  ```

- To make this persistent across reboots, add these modules to `/etc/modules`:
  ```bash
  echo usbip_host | sudo tee -a /etc/modules
  echo vhci_hcd | sudo tee -a /etc/modules
  ```

- Start the usbipd service:
  ```bash
  sudo usbipd -D
  ```

- Find the USB device for the 3D printer:
  ```bash
  sudo usbip list -l
  ```

- Example output:
  ```markdown
  - busid 1-1 (1a86:7523)
      QinHeng Electronics : CH340 serial converter
  ```

- Identify the **busid** for the printer (e.g., `1-1`).

- Bind the device to make it available for sharing:
  ```bash
  sudo usbip bind -b 1-1
  ```

## 2. Set Up the Server/NAS as a USB/IP Client/Instructor

The host system may has `usbip` available to be installed using apt, but mine has not, so here is a guide to get it quickly installed on any distro.
The key is running a privileged debian docker container to get those binaries nstalled on the host machine.

- Pull and run a Docker container with privileged mode:
  ```bash
  docker run --rm -it --privileged debian:bullseye bash
  ```

- Inside the container, install USB/IP tools:
  ```bash
  apt update && apt install -y usbip
  ```

- Attach the shared USB device from the Raspberry Pi:
  ```bash
  usbip attach -r 10.0.0.201 -b 1-1
  ```

- Verify the USB device is attached:
  ```bash
  ls /dev/ttyUSB*
  ```

- You should see the 3D printer appear as `/dev/ttyUSB0`.

