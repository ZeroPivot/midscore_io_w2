#!/bin/bash

# Update the package list
sudo apt-get update

# Install prerequisites
sudo apt-get install -y wget apt-transport-https software-properties-common

# Import the Microsoft GPG key
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -

# Register the Microsoft Ubuntu repository
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list)"

# Update the package list again
sudo apt-get update

# Install PowerShell
sudo apt-get install -y powershell

# Verify the installation
pwsh --version
