# Intro

This guide is for setting up a wireless-usb connection between an ancient 3d printer and an SBC.  
In this setup, a NAS server was used as the instructing unit, that runs an octoprint instance and binds the usb device to the container. 
The acting unit (that controls the 3d printer) is a raspberry pi zero W, that is connected to the 3d printer per usb and shares that usb conenction over LAN.

In the end, the octoprint docker container serves the app and sends commands, the PI receives them and passes them to the 3d printer.
If for whatever reason you also want this setup, follow along.

# Setup 

## 1. Set Up the Raspberry Pi as a USB/IP Server/actor

The Pi needs to have an sd card prepared (using e.g. pi imager). It needs to be connected to the printer via a physical USB cable and get `usbip` installed to share that connection to the network.

- Update the system and install USB/IP:
  ```bash
  sudo apt update
  ```
  ```bash
  sudo apt install -y usbip
  ```

- Load the necessary kernel modules:
  ```bash
  sudo modprobe usbip_host
  ```
  ```bash
  sudo modprobe vhci_hcd
  ```

- To make this persistent across reboots, add these modules to `/etc/modules`:
  ```bash
  echo usbip_host | sudo tee -a /etc/modules
  ```
  ```bash
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

- Attach the shared USB device from the Raspberry Pi using its ip:
  ```bash
  usbip attach -r 10.0.0.201 -b 1-1
  ```

- Verify the USB device is attached:
  ```bash
  ls /dev/ttyUSB*
  ```

- You should see the 3D printer appear as `/dev/ttyUSB0`.

## 3. Run Octoprint with the right docker arguments

- Adjust the docker run command for octoprint to include
  - `--privileged`
  - `---device=/dev/ttyUSB0` (adjust device name if needed)

- Resulting docker run command example:
  ```bash
  docker run -d \
  --device=/dev/ttyUSB0 \
  --name octoprint \
  --privileged \
  --pull always \
  --restart always \
  -v "/homes/docker/Octoprint:/octoprint" \
  octoprint/octoprint:latest
  ```

## 4. Automate the PI

The PI will ned to run the usbip commands again after a reboot, to provide the connection again. 

- Create a shell script on the pi (adjust username if needed):
  ```bash
  nano /home/pi/start-usbip.sh
  ```

- Fill the script with the content of [start-script.sh](start-script.sh) and save (CTRL+X, Y, Enter)

- Create the crontab entry (as root, so the script runs as root)
  ```bash
  sudo crontab -e
  ```

- Add the line to run on boot (adjust username if needed) and save again (CTRL+X, Y, Enter):
  ```bash
  @reboot /home/pi/start-usbip.sh
  ```

- Reboot the pi with `sudo reboot` and run a debian container:
  ```bash
  docker run --rm -it --privileged debian:bullseye bash
  ```
- Check if connection succeeds from within the debian container's shell (no output means success):
  ```bash
  usbip attach -r 10.0.0.201 -b 1-1
  ```
