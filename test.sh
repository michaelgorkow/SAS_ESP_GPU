SAS_DEPLOYMENTDATA="SAS_Viya_deployment_data.zip"
SAS_MIRRORMANAGER_URL="https://support.sas.com/installation/viya/35/sas-mirror-manager/lax/mirrormgr-linux.tgz"
SAS_MIRROREXTENSIONS_URL="https://support.sas.com/installation/viya/35/sas-edge-extension/sas-edge-extension.tgz"
SAS_SOFTWAREREPOSITORY="sas-espedge-106-x64_redhat_linux_6-yum"
SAS_PACKAGELOCATION="espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum"
PYTHON_REQ="requirements.txt"
OPENCV_PACKAGELOCATON="OpenCV-x64-gpu/opencv-centos7-x64-rpm"
CONTAINER_NAME="test"
CONTAINER_TAG="1"
CONTAINER_BUILD="YES"
CONTAINER_PUSH="NO"
OTHER_ARGUMENTS=()

docker build -t $CONTAINER_NAME:$CONTAINER_TAG \
                --build-arg OPENCV_PACKAGELOCATION="$OPENCV_PACKAGELOCATION" .
