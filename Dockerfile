FROM ubuntu:20.04

# ARG DOWNLOAD_URL=http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/integration/12.0.2.0-ACE-LINUX64-DEVELOPER.tar.gz

ARG DOWNLOAD_URL=https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/integration/12.0.3.0-ACE-LINUX64-DEVELOPER.tar.gz
ARG PRODUCT_LABEL=ace-12.0.3.0
# ARG MQ_PACKAGES="ibmmq-server ibmmq-java ibmmq-jre ibmmq-gskit ibmmq-msg-.* ibmmq-client ibmmq-sdk ibmmq-samples ibmmq-ft*"

# Prevent errors about having no terminal when using apt-get
ENV DEBIAN_FRONTEND noninteractive

# Install ACE v12.0.2.0 and accept the license
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    bash \
    curl \
    file \
    grep \
    maven \
    mount \
    sudo \
    tar \
    util-linux
 
RUN mkdir /opt/ibm && echo Downloading package ${DOWNLOAD_URL} && \
    curl ${DOWNLOAD_URL} | tar zx --directory /opt/ibm && \
    mv /opt/ibm/${PRODUCT_LABEL} /opt/ibm/ace-12 && \
    /opt/ibm/ace-12/ace make registry global accept license deferred

# Configure the system
RUN echo "ACE_12:" > /etc/debian_chroot \
  && echo ". /opt/ibm/ace-12/server/bin/mqsiprofile" >> /root/.bashrc

# mqsicreatebar prereqs; need to run "Xvfb -ac :99 &" and "export DISPLAY=:99"  
RUN apt-get -y install libgtk2.0-0 libxtst6 xvfb curl libswt-gtk-4-java libswt-gtk-4-jni jq \
    vim \
    maven \
    git \
    zip \
    unzip


# Install PWSH

# Update the list of packages
RUN apt-get update
# Install pre-requisite packages.
RUN apt-get install -y wget apt-transport-https software-properties-common
# Download the Microsoft repository GPG keys
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
# Register the Microsoft repository GPG keys
RUN dpkg -i packages-microsoft-prod.deb
# Update the list of packages after we added packages.microsoft.com
RUN apt-get update
# Install PowerShell
RUN apt-get install -y powershell
# Start PowerShell
#pwsh

# Install az copy
RUN wget https://aka.ms/downloadazcopy-v10-linux
 
#Expand Archive
RUN tar -xvf downloadazcopy-v10-linux
 
#(Optional) Remove existing AzCopy version
#RUN rm /usr/bin/azcopy
 
#Move AzCopy to the destination you want to store it
RUN cp ./azcopy_linux_amd64_*/azcopy /usr/bin/

COPY ./plugins/wmb-baseline-plugin-3.4.0.jar /opt/ibm/ace-12/tools/plugins/
COPY ./plugins/wmb-baseline-plugin-jplugin-3.4.1-distribution.zip /opt/ibm/ace-12/tools/plugins/
# Uncommented the code for copy of settings.xml file
COPY ./config/*.xml ./

# added 1909 - 0608
COPY ./config/settings.xml ./maven/.m2/

# 2209
#COPY ./1118/* /tmp

WORKDIR = /opt/ibm/ace-12/tools/plugins/
RUN unzip /opt/ibm/ace-12/tools/plugins/wmb-baseline-plugin-jplugin-3.4.1-distribution.zip

# Set BASH_ENV to source mqsiprofile when using docker exec bash -c
ENV BASH_ENV=/opt/ibm/ace-12/server/bin/mqsiprofile

# Create a user to run as, create the ace workdir, and chmod script files
# RUN useradd --uid 1001 --create-home --home-dir /home/aceuser --shell /bin/bash -G mqbrkrs,sudo aceuser \
#   && su - aceuser -c "export LICENSE=accept && . /opt/ibm/ace-12/server/bin/mqsiprofile && mqsicreateworkdir /home/aceuser/ace-server" \
#   && echo ". /opt/ibm/ace-12/server/bin/mqsiprofile" >> /home/aceuser/.bashrc

RUN su - root -c "export LICENSE=accept && . /opt/ibm/ace-12/server/bin/mqsiprofile && mqsicreateworkdir /root"

USER root
RUN echo "Xvfb -ac :100 &" >> /root/.bashrc
RUN echo "export DISPLAY=:100" >> /root/.bashrc
# ENTRYPOINT ["bash"]

# aceuser
# USER 1001
# ENTRYPOINT ["bash"]

##### Azure Self hosted Agent #####

RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    git \
    iputils-ping \
    netcat \
    lsb-release \
    software-properties-common

# Install Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
#RUN curl -LO https://dl.k8s.io/release/v1.25.2/bin/linux/amd64/kubectl
RUN install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install azure devops extentions
RUN az config set extension.use_dynamic_install=yes_without_prompt
RUN az extension add --name azure-devops
#RUN az devops extension install --extension-id "custom-terraform-tasks" --publisher-id "ms-devlabs" --org https://dev.azure.com/mayankahuja

ENV TARGETARCH=linux-x64
WORKDIR /azp
COPY ./start.sh .
RUN chmod +x start.sh
RUN chmod +x ./start.sh

ENTRYPOINT ["./start.sh"]
