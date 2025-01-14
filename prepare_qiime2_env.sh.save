#!/bin/bash

echo "Starting QIIME2 environment setup..."

# Step 1: Check if conda is installed, and install Miniconda if it's missing
if ! command -v conda &> /dev/null
then
    echo "Conda not found. Installing Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda
    export PATH="$HOME/miniconda/bin:$PATH"
    echo 'export PATH="$HOME/miniconda/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
else
    echo "Conda is already installed."
fi

# Step 2: Download the QIIME2 environment file
echo "Downloading QIIME2 environment file..."
wget -O qiime2-2023.5-py38-linux-conda.yml https://data.qiime2.org/distro/core/qiime2-2023.5-py38-linux-conda.yml

# Step 3: Create the QIIME2 environment
echo "Creating QIIME2 environment..."
conda env create -n qiime2-2023.5 --file qiime2-2023.5-py38-linux-conda.yml

# Step 4: Initialize Conda for bash
echo "Initializing Conda for bash..."
conda init bash

# Reload the shell to apply changes
echo "Reloading shell..."
exec bash

# Step 5: Activate the QIIME2 environment
echo "Activating QIIME2 environment..."
conda activate qiime2-2023.5

# Step 6: Verify QIIME2 installation
echo "Verifying QIIME2 installation..."
qiime --version

echo "QIMME2 environment setup completed successfully."
