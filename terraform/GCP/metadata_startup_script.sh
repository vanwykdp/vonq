#!/bin/bash
exec > >(tee /var/log/startup-script.log) 2>&1

echo "Starting Apache setup..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 php

echo "Creating home page..."
echo 'Welcome!' > /var/www/html/index.html

echo "Creating API endpoint..."
echo 'Hello World!' > /var/www/html/api


echo "Starting Apache..."
systemctl start apache2
systemctl enable apache2

echo "Apache setup completed"
