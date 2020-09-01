FROM nvidia/cuda:10.2-cudnn7-runtime-centos7
MAINTAINER Michael Gorkow <michael.gorkow@sas.com>

# Change to location of your files if necessary
ARG OPENCV_DEBS=opencv-centos7-x64-deb/opencv-centos7-x64-deb
ARG SASESP_DEBS=espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum
ARG SASLICENSE=SAS_Viya_deployment_data.zip

# Copy SAS Event Stream Processing & OpenCV files
RUN mkdir -p /opt/opencv/ && \
    mkdir -p /opt/sas_installfiles/
COPY ${OPENCV_DEBS} /opt/opencv
COPY ${SASESP_DEBS} /opt/sas_installfiles
ADD ${SASLICENSE} /opt/sas_installfiles

# Install yum packages
RUN yum -y update && yum install -y epel-release && \
    yum -y install \
           wget \
           unzip \
           numactl \
           java-1.8.0-openjdk \
           NetworkManager \
           python3 \
           graphviz

### Python pip packages
# Installation
RUN pip3


# Install SAS ESP
RUN yum -y install /opt/sas_installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/basic/* \
		   /opt/sas_installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/analytics/* \
		   /opt/sas_installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/astore/* \
		   /opt/sas_installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/textanalytics/* \
		   /opt/sas_installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/gpu/* \
		   /opt/sas_installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/upgradepkgs/*

#Apply license file to ESP
RUN unzip /opt/sas_installfiles/SAS_Viya_deployment_data.zip
RUN \cp /opt/sas_installfiles/licenses/SASViyaV0300_09QCC6_Linux_x86-64.txt /opt/sas/viya/home/SASEventStreamProcessingEngine/6.2/etc/license/license.txt

#Set environment variables
ENV DFESP_HOME="/opt/sas/viya/home/SASEventStreamProcessingEngine/6.2"

#Add ESP plugins
#RUN wget https://gitlab.sas.com/germgk/esp-gpu-docker/-/archive/master/esp-gpu-docker-master.zip?path=esp_plugins -P /tmp
#RUN unzip /tmp/esp-gpu-docker-master.zip\?path\=esp_plugins -d /tmp && mv /tmp/esp-gpu-docker-master-esp_plugins/esp_plugins/*.so $DFESP_HOME/lib

RUN mkdir -p /data/notebooks/

#Add additional ESP adapters
COPY additional_adapters/bin/. $DFESP_HOME/bin/
COPY additional_adapters/lib/. $DFESP_HOME/lib/
COPY additional_adapters/etc/. $DFESP_HOME/etc/

#Set environment variables
ENV ESP_PORT=9900
ENV ESP_PUBSUB_PORT=31416
ENV ESP_LOGLEVEL=error
ENV ESP_MAS_THREADS=1
ENV MAS_M2PATH=/opt/sas/viya/home/SASFoundation/misc/embscoreeng/mas2py.py
ENV MAS_PYPATH=/opt/conda/envs/python_sas/bin/python
ENV MAS_PYLOG_LEVEL=ERROR 
ENV MAS_PYLOG_FILE=/opt/maspylog.txt
ENV DFESP_JAVA_TRUSTSTORE=/data/tls/trustedcerts.jks
ENV SSLCALISTLOC=/data/tls/trustedcerts.pem
ENV JUPYTERLAB_PORT=8080
ENV JUPYTERLAB_NBDIR=/data/notebooks/

#Create ESP start script (setting LD_LIBRARY_PATH for SAS)
RUN echo -e '#!/bin/bash\n' \
            'export LD_LIBRARY_PATH=/opt/sas/viya/home/SASEventStreamProcessingEngine/6.2/lib:/opt/sas/viya/home/SASFoundation/sasexe\n' \
            '$DFESP_HOME/bin/dfesp_xml_server -http $ESP_PORT -pubsub $ESP_PUBSUB_PORT -loglevel "esp=$ESP_LOGLEVEL" -mas-threads $ESP_MAS_THREADS' > /opt/sas/viya/home/SASEventStreamProcessingEngine/6.2/bin/dfesp_xml_server.sh

#Create start script
RUN echo -e '#!/bin/bash\n' \
            '/opt/sas/viya/home/SASEventStreamProcessingEngine/6.2/bin/dfesp_xml_server.sh &\n' \
            'jupyter lab --port $JUPYTERLAB_PORT --ip 0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.notebook_dir=$JUPYTERLAB_NBDIR --NotebookApp.allow_origin='*'\n' \
            'while true \n' \
            'do \n' \
            'sleep 3600 \n' \
            'done'> /opt/start.sh
RUN chmod +x /opt/start.sh /opt/sas/viya/home/SASEventStreamProcessingEngine/6.2/bin/dfesp_xml_server.sh

# Calls start script
CMD /opt/start.sh
