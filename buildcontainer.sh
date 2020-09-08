# Default variables
SAS_DEPLOYMENTDATA="SAS_Viya_deployment_data.zip"
SAS_MIRRORMANAGER_URL="https://support.sas.com/installation/viya/35/sas-mirror-manager/lax/mirrormgr-linux.tgz"
SAS_MIRROREXTENSIONS_URL="https://support.sas.com/installation/viya/35/sas-edge-extension/sas-edge-extension.tgz"
SAS_SOFTWAREREPOSITORY="sas-espedge-106-x64_redhat_linux_6-yum"
SAS_PACKAGELOCATION="espedge_repos/sas-espedge-106-x64_redhat_linux_6-yum"
SASESP_PLUGINS="esp_addons/esp_plugins"
SASESP_ADAPTERS="esp_addons/additional_adapters"
PYTHON_REQ="requirements.txt"
OPENCV_PACKAGELOCATION="OpenCV-x64-gpu/opencv-centos7-x64-rpm"
CONTAINER_NAME="esp_gpu"
CONTAINER_TAG="6_2"
CONTAINER_BUILD="YES"
CONTAINER_PUSH="NO"
OTHER_ARGUMENTS=()

# User provided variables
for arg in "$@"
do
    case $arg in
        -sdd*|--sas_deployment_data*)
        SAS_DEPLOYMENTDATA="${arg#*=}"
        shift
        ;;
        -smmdu*|--sas_mirrormanager_url*)
        SAS_MIRRORMANAGER_URL="${arg#*=}"
        shift
        ;;
        -smedu*|--sas_mirrorextensions_url*)
        SAS_MIRROREXTENSIONS_URL="${arg#*=}"
        shift
        ;;
        -ssr*|--sas_software_repository*)
        SAS_SOFTWAREREPOSITORY="${arg#*=}"
        shift
        ;;
        -spl*|--sas_package_location*)
        SAS_PACKAGELOCATION="${arg#*=}"
        shift
        ;;
        -spll*|--sas_plugins_location*)
        SASESP_PLUGINS="${arg#*=}"
        shift
        ;;
        -sadl*|--sas_adapters_location*)
        SASESP_ADAPTERS="${arg#*=}"
        shift
        ;;
        -pr*|--python_req*)
        PYTHON_REQ="${arg#*=}"
        shift
        ;;
        -opl*|--opencv_package_location*)
        OPENCV_PACKAGELOCATION="${arg#*=}"
        shift
        ;;
        -cn*|--container_name*)
        CONTAINER_NAME="${arg#*=}"
        shift
        ;;
        -ct*|--container_tag*)
        CONTAINER_TAG="${arg#*=}"
        shift
        ;;
        -cb*|--container_build*)
        CONTAINER_BUILD="${arg#*=}"
        shift
        ;;
        -cp*|--container_push*)
        CONTAINER_PUSH="${arg#*=}"
        shift
        ;;
        *)
        OTHER_ARGUMENTS+=("$1")
        shift # Remove generic argument from processing
        ;;
    esac
done

# Intro
printf '#%.0s' {1..100}; printf '\n';
printf '#%.0s' {1..100}; printf '\n';
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Event Stream Processing on Edge"
printf '##### %-88s #####\n' "Version 6.2"
printf '##### %-88s #####\n'
printf '#%.0s' {1..100}; printf '\n';
printf '##### %-88s #####\n' "Source: github.com/Mentos05/SAS_ESP_GPU"
printf '#%.0s' {1..100}; printf '\n';
printf '#%.0s' {1..100}; printf '\n';
printf '##### %-88s #####\n' "Variables"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Deployment Data:"
printf '##### %-88s #####\n' "$SAS_DEPLOYMENTDATA"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Mirror Manager URL:"
printf '##### %-88s #####\n' "$SAS_MIRRORMANAGER_URL"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Mirror Extensions URL:"
printf '##### %-88s #####\n' "$SAS_MIRROREXTENSIONS_URL"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Package Location:"
printf '##### %-88s #####\n' "$SAS_PACKAGELOCATION"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Plugins Location:"
printf '##### %-88s #####\n' "$SASESP_PLUGINS"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "SAS Adapters Location:"
printf '##### %-88s #####\n' "$SASESP_ADAPTERS"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "Python Requirements File:"
printf '##### %-88s #####\n' "$PYTHON_REQ"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "OpenCV Package Location:"
printf '##### %-88s #####\n' "$OPENCV_PACKAGELOCATION"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "Docker Container Name:"
printf '##### %-88s #####\n' "$CONTAINER_NAME"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "Docker Container Tag:"
printf '##### %-88s #####\n' "$CONTAINER_TAG"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "Build Container:"
printf '##### %-88s #####\n' "$CONTAINER_BUILD"
printf '##### %-88s #####\n'
printf '##### %-88s #####\n' "Push Container:"
printf '##### %-88s #####\n' "$CONTAINER_PUSH"
printf '##### %-88s #####\n'
printf '#%.0s' {1..100}; printf '\n';
printf '#%.0s' {1..100}; printf '\n'; printf '\n';

while true; do
    read -p "Are these settings correct?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Check SAS deployment data
echo "NOTE: Verifying SAS_Viya_deployment_data.zip"
if ls $SAS_DEPLOYMENTDATA 1> /dev/null 2>&1; then
    echo "NOTE: $SAS_DEPLOYMENTDATA found in $(pwd)"
else
    echo "$SAS_DEPLOYMENTDATA not found in $(pwd). Exiting."
    exit 1
fi

# Check SAS Event Stream Processing on Edge repository
echo "NOTE: Verifying SAS Event Stream Processing on Edge files"
if ! ls $SAS_PACKAGELOCATION/analytics/sas-* 1> /dev/null 2>&1; then
   echo "NOTE: SAS Event Stream Processing on Egde repository does not exist. Begin download."
   echo "NOTE: Changing Package Location from $SAS_PACKAGELOCATION to espedge_repos/$SAS_SOFTWAREREPOSITORY"
   SAS_PACKAGELOCATION="espedge_repos/$SAS_SOFTWAREREPOSITORY"
   # Check SAS Mirror Manager
   if ls mirrormgr 1> /dev/null 2>&1; then
      echo "NOTE: SAS Mirror Manager exists."
   else
      echo "NOTE: Downloading SAS Mirror Manager."
      wget $SAS_MIRRORMANAGER_URL -O mirrormgr-linux.tgz && tar zxfv mirrormgr-linux.tgz && rm mirrormgr-linux.tgz
   fi
   # Check SAS Mirror Manager Extensions
   if ls edge_mirror.sh 1> /dev/null 2>&1; then
      echo "NOTE: SAS Mirror Manager Extension exists."
   else
      echo "NOTE: Downloading SAS Mirror Extensions for SAS Event Stream Processing for Edge Computing."
      wget $SAS_MIRROREXTENSIONS_URL -O sas-edge-extension.tgz && tar zxfv sas-edge-extension.tgz && rm sas-edge-extension.tgz
   fi
   # Download SAS Event Stream Processing on Edge
   echo "NOTE: Downloading SAS Event Stream Processing on Edge files."
   bash edge_mirror.sh $SAS_SOFTWAREREPOSITORY /
else
   echo "NOTE: SAS Event Stream Processing on Egde repository exists. Skipping Download"
fi

# Check OpenCV files
echo "NOTE: Verifying OpenCV files"
if ! ls  $OPENCV_PACKAGELOCATION/* 1> /dev/null 2>&1; then
   echo "NOTE: Could not find OpenCV files. Getting submodules."
   git submodule init
   git submodule update --recursive --remote
else
   echo "NOTE: OpenCV files found."
fi

# Building Docker container
if [ $CONTAINER_BUILD == "YES" ]; then
   echo "NOTE: Building Docker container $CONTAINER_NAME:$CONTAINER_TAG"
   docker build -t $CONTAINER_NAME:$CONTAINER_TAG \
                --build-arg SAS_PACKAGELOCATION=${SAS_PACKAGELOCATION} \
                --build-arg SAS_DEPLOYMENTDATA=${SAS_DEPLOYMENTDATA} \
                --build-arg SASESP_PLUGINS=${SASESP_PLUGINS} \
                --build-arg SASESP_ADAPTERS=${SASESP_ADAPTERS} \
                --build-arg OPENCV_PACKAGELOCATION=${OPENCV_PACKAGELOCATION} \
                --build-arg PYTHON_REQ=${PYTHON_REQ} .
else
   echo "NOTE: Skipping docker build."
fi

# Pushing Docker container
if [ $CONTAINER_PUSH == "YES" ]; then
   echo "NOTE: Pushing Docker container $CONTAINER_NAME:$CONTAINER_TAG to repository."
   docker push $CONTAINER_NAME:$CONTAINER_TAG
else
   echo "NOTE: Skipping docker push."
fi

echo "Finished."
exit
