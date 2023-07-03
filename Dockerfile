# Define base image.
FROM nvidia/cudagl:11.3.1-devel

# Set environment variables.
## Set non-interactive to prevent asking for user inputs blocking image creation.
ENV DEBIAN_FRONTEND=noninteractive
## Set timezone as it is required by some packages.
ENV TZ=Europe/Berlin
## CUDA architectures, required by tiny-cuda-nn.
ENV TCNN_CUDA_ARCHITECTURES=75
## CUDA Home, required to find CUDA in some packages.
ENV CUDA_HOME="/usr/local/cuda"

# Install required apt packages.
# RUN echo "deb http://us.archive.ubuntu.com/ubuntu/ xenial main restricted
# deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates main restricted
# deb http://us.archive.ubuntu.com/ubuntu/ xenial universe
# deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates universe
# deb http://us.archive.ubuntu.com/ubuntu/ xenial multiverse
# deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates multiverse
# deb http://us.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse

# deb http://security.ubuntu.com/ubuntu xenial-security main restricted
# deb http://security.ubuntu.com/ubuntu xenial-security universe
# deb http://security.ubuntu.com/ubuntu xenial-security multiverse" >& /etc/apt/sources.list
# RUN apt-get install software-properties-common
RUN apt-get update && apt-get install -y software-properties-common
# && add-apt-repository ppa:beineri/opt-qt-5.15.2-bionic
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ffmpeg \
    git \
    libatlas-base-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-test-dev \
    libcgal-dev \
    libeigen3-dev \
    libfreeimage-dev \
    libgflags-dev \
    libglew-dev \
    libgoogle-glog-dev \
    libmetis-dev \
    libprotobuf-dev \
    libqt5opengl5-dev \
    libsuitesparse-dev \
    nano \
    protobuf-compiler \
    python3.8-dev \
    python3-pip \
    qtbase5-dev \
    wget \
    sudo

# Install GLOG (required by ceres).
RUN git clone --branch v0.6.0 https://github.com/google/glog.git --single-branch && \
    cd glog && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j `nproc` && \
    make install && \
    cd ../.. && \
    rm -r glog
# Add glog path to LD_LIBRARY_PATH.
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib"

# Install Ceres-solver (required by colmap).
RUN git clone --branch 2.1.0 https://ceres-solver.googlesource.com/ceres-solver.git --single-branch && \
    cd ceres-solver && \
    git checkout $(git describe --tags) && \
    mkdir build && \
    cd build && \
    cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF && \
    make -j `nproc` && \
    make install && \
    cd ../.. && \
    rm -r ceres-solver

# Install colmap.
RUN git clone --branch 3.7 https://github.com/colmap/colmap.git --single-branch && \
    cd colmap && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j `nproc` && \
    make install && \
    cd ../.. && \
    rm -r colmap
    
# Create non root user and setup environment.
RUN useradd -m -d /home/user -g root -G sudo -u 1000 user
RUN usermod -aG sudo user
# Set user password
RUN echo "user:user" | chpasswd
# Ensure sudo group users are not asked for a password when using sudo command by ammending sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to new uer and workdir.
USER 1000
WORKDIR /home/user

# Add local user binary folder to PATH variable.
ENV PATH="${PATH}:/home/user/.local/bin"
SHELL ["/bin/bash", "-c"]

# Upgrade pip and install packages.
RUN python3.8 -m pip install --upgrade pip setuptools pathtools promise
# Install pytorch and submodules.
RUN python3.8 -m pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113
# Install tynyCUDNN.
RUN python3.8 -m pip install git+https://github.com/NVlabs/tiny-cuda-nn.git#subdirectory=bindings/torch

# Copy nerfstudio folder and give ownership to user.
ADD . /home/user/nerfstudio
USER root
RUN chown -R user /home/user/nerfstudio
USER 1000

# Install nerfstudio dependencies.
RUN cd nerfstudio && \
    python3.8 -m pip install -e . && \
    cd ..

# Change working directory
WORKDIR /workspace

# Install nerfstudio cli auto completion and enter shell if no command was provided.
CMD ns-install-cli --mode install && /bin/bash

