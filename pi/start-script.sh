#!/bin/bash
sudo modprobe usbip_host
sudo modprobe vhci_hcd
echo usbip_host | sudo tee -a /etc/modules
echo vhci_hcd | sudo tee -a /etc/modules
sudo usbipd -D
sudo usbip list -l # for debugging
sudo usbip bind -b 1-1
