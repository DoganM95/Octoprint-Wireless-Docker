# Intro

This guide is for setting up a wireless-usb connection between an ancient 3d printer and an SBC.  
In this setup, a NAS server was used as the instructing unit, that runs an octoprint instance and binds the usb device to the container. 
The acting unit (that controls the 3d printer) is a raspberry pi zero W, that is connected to the 3d printer per usb and shares that usb conenction over LAN.

In the end, the octoprint docker container serves the app and sends commands, the PI receives them and passes them to the 3d printer.
If for whatever reason you also want this setup, follow along.

# Infos

## Pros

- **Performance:** The hardware that runs octoprint in this case can be as powerful as you want, e.g. enterprise servers
- **Simplicity:** The setup of the raspberry pi becomes a bit simpler
- **Centralization:** The server becomes the central point serving octoprint, allowing using its files and combining other apps with it, as well as automation in a simpler way
- **Singleton:** This octoprint server can serve many printers at once (if octoprint allows x printers in one app)

## Cons

- **Network dependency:** This setup requires both devices to be connected to the same network
- **Stability:** In an ideal setup, the wifi connection would be always stable. But nothing is ideal, so eventually at some point the print will randomly stop due to disconnection/latency
- **Increased complexity:** This setup is not as easy as just flashing a pi with a custom image, especially having to set up the usb/ip connection and troubleshootings
- **Power consumption:** A powerful machine serving octoprint probably consumes more energy than a 10 Watt pi

Overall, this setup was an experiment which worked fine, but should only be used if you know what you are doing and have very specific requirements. 
The good thing is, after setting the server up successfully, it should be possible to just leave out the PI and plug the printer in to the server directly via usb, turning the server into a  
very, very powerfuly Octoprint server with connectivity issues fixed, due to having a wired connection, eliminating the pi completely.

Also proceeed with caution when using this, when my print with the usb/ip setup failed after around 5 hours due to network instability, the hotend was still 200C and the bed still 50C, whith the printer having no movement at all. This is a potential fire/gas hazard with the filament coming out black, when extruding after a while.

# Setup 

## 1. Set Up the Raspberry Pi as a USB/IP Server/actor

The Pi needs to have an sd card prepared (using e.g. pi imager). It needs to be connected to the printer via a physical USB cable and get `usbip` installed to share that connection to the network.

- Update the system and install USB/IP:
  ```bash
  sudo apt update && sudo apt install -y usbip
  ```

- Load the necessary kernel modules:
  ```bash
  sudo modprobe usbip_host && sudo modprobe vhci_hcd
  ```

- To make this persistent across reboots, add these modules to `/etc/modules`:
  ```bash
  echo usbip_host | sudo tee -a /etc/modules &&  echo vhci_hcd | sudo tee -a /etc/modules
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
  - `--device=/dev/ttyUSB0` (adjust device name if needed)
  - `-v "/var/run/docker.sock:/var/run/docker.sock" \` (needed later for automation)

- Resulting docker run command example:
  ```bash
  docker run -d \
  --device=/dev/ttyUSB0 \
  --name octoprint \
  --privileged \
  --pull always \
  --restart always \
  -v "/homes/docker/Octoprint:/octoprint" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  octoprint/octoprint:latest
  ```

## 4. Automate the PI

The PI will ned to run the usbip commands again after a reboot, to provide the connection again. 

- Create a shell script on the pi (adjust username if needed):
  ```bash
  nano /home/pi/start-usbip.sh
  ```

- Fill the script with the content of [start-script.sh](start-script.sh) and save (CTRL+X, Y, Enter)

- Make the script executable:
  ```bash
  chmod +x /home/pi/start-usbip.sh
  ```

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
  docker run --rm -it --privileged --network=host debian:bullseye bash
  ```
- Check if connection succeeds from within the debian container's shell (no output means success):
  ```bash
  usbip attach -r 10.0.0.201 -b 1-1
  ```

## 5. Automate Octoprint

When the connection between the pi and the server is lost, the usbip command to connect needs to be ran again. 
The quickest way for that is to integrate the docker debian command into octoprint, to be ran on each restart:

- In the Octoprint Ui open settings -> server -> Restart OctoPrint, which should be `sudo service octoprint restart`

- Change it to
  ```bash
  sudo systemctl restart octoprint && docker run --rm --privileged debian:bullseye bash -c "apt update && apt install -y usbip && usbip attach -r 10.0.0.201 -b 1-1"
  ```
