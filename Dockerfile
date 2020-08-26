FROM nvidia/cuda:10.1-cudnn7-devel-centos7
MAINTAINER Michael Gorkow <michael.gorkow@sas.com>

#Install ESP dependencies
RUN yum -y update && yum -y install wget unzip numactl java-1.8.0-openjdk NetworkManager epel-release

#Create and set working directory + add deployment data
RUN mkdir -p /opt/sas/installfiles
ADD SAS_Viya_deployment_data.zip /opt/sas/installfiles
WORKDIR /opt/sas/installfiles
RUN wget https://support.sas.com/installation/viya/35/sas-mirror-manager/lax/mirrormgr-linux.tgz && tar zxfv mirrormgr-linux.tgz
RUN wget https://support.sas.com/installation/viya/35/sas-edge-extension/sas-edge-extension.tgz && tar zxfv sas-edge-extension.tgz

#Download and install ESP rpm files
RUN ./edge_mirror.sh  sas-espedge-106-x64_redhat_linux_6-yum / 
RUN yum -y install /opt/sas/installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/basic/* \
		   /opt/sas/installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/analytics/* \
		   /opt/sas/installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/astore/* \
		   /opt/sas/installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/textanalytics/* \
		   /opt/sas/installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/gpu/* \
		   /opt/sas/installfiles/espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum/upgradepkgs/*

#Apply license file to ESP
RUN unzip /opt/sas/installfiles/SAS_Viya_deployment_data.zip
RUN \cp /opt/sas/installfiles/licenses/SASViyaV0300_09QCC6_Linux_x86-64.txt /opt/sas/viya/home/SASEventStreamProcessingEngine/6.2/etc/license/license.txt

#Set environment variables
ENV DFESP_HOME="/opt/sas/viya/home/SASEventStreamProcessingEngine/6.2"

#Add ESP plugins
RUN wget https://gitlab.sas.com/germgk/esp-gpu-docker/-/archive/master/esp-gpu-docker-master.zip?path=esp_plugins -P /tmp
RUN unzip /tmp/esp-gpu-docker-master.zip\?path\=esp_plugins -d /tmp && mv /tmp/esp-gpu-docker-master-esp_plugins/esp_plugins/*.so $DFESP_HOME/lib

#Install Anaconda
RUN yum install -y bzip2 ca-certificates curl bash sudo git \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    mercurial subversion graphviz && \
    yum-builddep -y pygame

RUN wget https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh

#Create Anaconda Environment with Python 3.7 + Jupyter Lab + various packages
ENV PATH $PATH:/opt/conda/bin
RUN conda update --all -y && conda install nb_conda_kernels cython conda-build -y
ADD jupyterlab_environments /opt/jupyterlab_environments
RUN curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash - && sudo yum install -y nodejs
RUN for env_file in /opt/jupyterlab_environments/*; do conda env create -f $env_file; done

RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
	jupyter labextension install plotlywidget && \
	jupyter labextension install jupyter-leaflet

#Install OpenCV from Source for extended codec support (video saving) -> uses CUDA support
RUN yum -y install epel-release http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm 
RUN yum -y install git gcc gcc-c++ cmake3 qt5-qtbase-devel \
    python python-devel python-pip cmake python-devel python34-numpy \
    gtk2-devel libpng-devel jasper-devel openexr-devel libwebp-devel \
    libjpeg-turbo-devel libtiff-devel libdc1394-devel tbb-devel numpy \
    eigen3-devel gstreamer-plugins-base-devel freeglut-devel mesa-libGL jansson \
    mesa-libGL-devel libv4l-devel ffmpeg ffmpeg-devel make gstreamer1-devel \
    gstreamer1-plugins-base-devel openblas-devel gstreamer1-plugins-good libcanberra-gtk3
Run git clone https://github.com/opencv/opencv.git /opt/opencv/ && \
    git clone https://github.com/opencv/opencv_contrib.git /opt/opencv_contrib/ && \
    mkdir /opt/opencv/build
WORKDIR /opt/opencv/build
Run cmake3 -DCMAKE_CXX_FLAGS="-fPIC " \
           -DPYTHON3_PACKAGES_PATH="/opt/conda/envs/python_sas/lib/python3.7/site-packages" \
           -DPYTHON3_LIBRARY="/opt/conda/envs/python_sas/lib/libpython3.7m.a" \
           -DPYTHON3_NUMPY_INCLUDE_DIRS="/opt/conda/envs/python_sas/lib/python3.7/site-packages/numpy/core/include" \
           -DPYTHON3_EXECUTABLE="/opt/conda/envs/python_sas/bin/python" \
           -DPYTHON3_INCLUDE_DIR="/opt/conda/envs/python_sas/include/python3.7m" \
           -DOPENCV_GENERATE_PKGCONFIG="1" \
           -DOPENCV_EXTRA_MODULES_PATH="/opt/opencv_contrib/modules" \
           -DWITH_FFMPEG=1 \
           -DWITH_GSTREAMER="1" \
	   -DWITH_CUDA="1" \
           -DWITH_CUBLAS="1" \
           -DCUDA_FAST_MATH="1" \
           -DENABLE_FAST_MATH="1" ..
Run make all -j$(nproc) && make install -j$(nproc)
RUN ln -s /usr/local/lib64/pkgconfig/opencv4.pc /usr/share/pkgconfig/ && \
    cp /opt/conda/envs/python_sas/lib/python3.7/site-packages/cv2/config-3.7.py /opt/conda/envs/python_sas/lib/python3.7/site-packages/cv2/config-3.6.py

#Install CMU OpenPose from Source https://github.com/CMU-Perceptual-Computing-Lab/openpose
RUN yum -y install protobuf-compiler protobuf-devel opencv-devel gflags-devel \
    glog-devel openblas-devel hdf5-devel lmdb-devel snappy-devel atlas-devel && \
    yum -y install http://repo.okay.com.mx/centos/7/x86_64/release/okay-release-1-1.noarch.rpm && yum -y install boost155-devel
RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose /opt/openpose/ && \
    git clone https://github.com/CMU-Perceptual-Computing-Lab/caffe.git /opt/openpose/3rdparty/caffe/ && \
    git clone https://github.com/pybind/pybind11.git /opt/openpose/3rdparty/pybind11/ && \
    mkdir /opt/openpose/3rdparty/caffe/build /opt/openpose/build
# Name changes in OpenCV v4 ...
RUN sed -i "s|CV_LOAD_IMAGE_COLOR|cv::IMREAD_COLOR|g" /opt/openpose/3rdparty/caffe/src/caffe/layers/window_data_layer.cpp && \
    sed -i "s|CV_LOAD_IMAGE_COLOR|cv::IMREAD_COLOR|g" /opt/openpose/3rdparty/caffe/src/caffe/util/io.cpp && \
    sed -i "s|CV_LOAD_IMAGE_GRAYSCALE|cv::IMREAD_GRAYSCALE|g" /opt/openpose/3rdparty/caffe/src/caffe/util/io.cpp && \
    sed -i "s|CV_LOAD_IMAGE_GRAYSCALE|cv::IMREAD_GRAYSCALE|g" /opt/openpose/examples/tests/resizeTest.cpp
WORKDIR /opt/openpose/3rdparty/caffe/build
RUN cmake3 -DCMAKE_CXX_FLAGS_DEBUG="-g" \
           -DCMAKE_CXX_FLAGS="-fPIC -fext-numeric-literals" \
           -DBLAS="Open" \
           -DUSE_LEVELDB=0 \
           -DCMAKE_INSTALL_PREFIX="/opt/openpose/3rdparty/caffe/build/install/" ..
RUN make all -j$(nproc) && make install -j$(nproc)
WORKDIR /opt/openpose/build
RUN cmake3 -DBUILD_CAFFE=0 \
           -DCaffe_LIBS="/opt/openpose/3rdparty/caffe/build/install/lib64/libcaffe.so.1.0.0" \
           -DCMAKE_CXX_FLAGS="-fPIC" \
           -DBUILD_PYTHON=1 \
           -DCaffe_INCLUDE_DIRS="/opt/openpose/3rdparty/caffe/build/install/include" \
           -DCMAKE_INSTALL_PREFIX="/opt/openpose/build/install/" ..
RUN make all -j$(nproc) && \
    make install -j$(nproc)
RUN conda-develop -n python_sas /opt/openpose/build/install/python

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
