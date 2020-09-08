# Change to your locations or use --build-arg
ARG SAS_PACKAGELOCATION=espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum
ARG SAS_DEPLOYMENTDATA=SAS_Viya_deployment_data.zip
ARG SASESP_PLUGINS=esp_addons/esp_plugins
ARG SASESP_ADAPTER=esp_addons/additional_adapters
ARG OPENCV_PACKAGELOCATION=OpenCV-x64-gpu/opencv-centos7-x64-rpm
ARG PYTHON_REQ=requirements.txt

FROM nvidia/cuda:10.2-cudnn7-runtime-centos7
MAINTAINER Michael Gorkow <michael.gorkow@sas.com>
ENV DEBIAN_FRONTEND=noninteractive

# Arguments
ARG SAS_PACKAGELOCATION
ARG SAS_DEPLOYMENTDATA
ARG SASESP_PLUGINS
ARG SASESP_ADAPTER
ARG OPENCV_PACKAGELOCATION
ARG PYTHON_REQ

# Copy SAS Event Stream Processing, OpenCV and Python environment files
RUN mkdir -p /opt/opencv/ && \
    mkdir -p /opt/sas_installfiles/
COPY ${SAS_PACKAGELOCATION} /opt/sas_installfiles
ADD ${SAS_DEPLOYMENTDATA} /opt/sas_installfiles
COPY ${OPENCV_PACKAGELOCATION} /opt/opencv
ADD ${PYTHON_REQ} /opt

# Install required repositories and packages
RUN yum -y install epel-release \
                   http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm && \
    yum -y install qt5-qtbase \
                   unzip \
                   numactl \
                   gperftools-libs \
                   leveldb \
                   gcc \
                   gcc-c++ \
                   python3-devel \
                   ffmpeg \
                   xkeyboard-config \
                   graphviz \
                   libcanberra-gtk3

# Install Python packages
RUN pip3 install -U pip && \
    pip3 install -r /opt/${PYTHON_REQ}

# Install and configure Jupyter Lab and Addons
RUN curl -sL https://rpm.nodesource.com/setup_14.x | bash - && \
    yum install -y nodejs && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter labextension install plotlywidget && \
    jupyter labextension install jupyter-leaflet

RUN jupyter lab --generate-config
RUN python3 -c "from notebook.auth.security import set_password; set_password('sas', '/root/.jupyter/jupyter_notebook_config.json')" 

# Install OpenCV from repository files
RUN yum -y install /opt/opencv/*.rpm

# Install SAS Event Stream Processing
RUN yum -y install /opt/sas_installfiles/basic/* \
		   /opt/sas_installfiles/analytics/* \
		   /opt/sas_installfiles/astore/* \
		   /opt/sas_installfiles/textanalytics/* \
		   /opt/sas_installfiles/gpu/* \
		   /opt/sas_installfiles/upgradepkgs/*

# Apply license to SAS Event Stream Processing
RUN unzip /opt/sas_installfiles/${SAS_DEPLOYMENTDATA} -d /opt/sas_installfiles/ && \
    \cp /opt/sas_installfiles/licenses/*.txt /opt/sas/viya/home/SASEventStreamProcessingEngine/current/etc/license/license.txt

# Set Environment Variables
ENV DFESP_HOME=/opt/sas/viya/home/SASEventStreamProcessingEngine/current
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/sas/viya/home/SASEventStreamProcessingEngine/current/lib:/opt/sas/viya/home/SASFoundation/sasexe
ENV ESP_PORT=9900
ENV ESP_PUBSUB_PORT=31416
ENV ESP_LOGLEVEL=error
ENV ESP_MAS_THREADS=1
ENV MAS_M2PATH=/opt/sas/viya/home/SASFoundation/misc/embscoreeng/mas2py.py
ENV MAS_PYPATH=/usr/bin/python3
ENV MAS_PYLOG_LEVEL=ERROR 
ENV MAS_PYLOG_FILE=/opt/maspylog.txt
ENV DFESP_JAVA_TRUSTSTORE=/data/tls/trustedcerts.jks
ENV SSLCALISTLOC=/data/tls/trustedcerts.pem
ENV JUPYTERLAB_PORT=8080
ENV JUPYTERLAB_NBDIR=/data/notebooks/

# Postconfiguration
# Fix Tensorflow cudart error
RUN ln -s /usr/local/cuda/lib64/libcudart.so.10.2 /usr/lib64/libcudart.so.10.1
# Add additional SAS Event Stream Processing components
COPY ${SASESP_PLUGINS}/. $DFESP_HOME/lib
COPY ${SASESP_ADAPTER}/bin/. $DFESP_HOME/bin/
COPY ${SASESP_ADAPTER}/lib/. $DFESP_HOME/lib/
COPY ${SASESP_ADAPTER}/etc/. $DFESP_HOME/etc/

# Remove installation files
RUN rm -rf /opt/opencv /opt/sas_installfiles /opt/requirements.txt

# Run SAS Event Stream Processing & Jupyter Lab at Startup
CMD $DFESP_HOME/bin/dfesp_xml_server -http $ESP_PORT \
                                     -pubsub $ESP_PUBSUB_PORT \
                                     -loglevel "esp=$ESP_LOGLEVEL" \
                                     -mas-threads $ESP_MAS_THREADS & \
     jupyter lab --port $JUPYTERLAB_PORT \
                 --ip 0.0.0.0 \
                 --allow-root \
                 --no-browser \
                 --NotebookApp.token='' \
                 --NotebookApp.password='' \
                 --NotebookApp.notebook_dir=$JUPYTERLAB_NBDIR \
                 --NotebookApp.allow_origin='*'
