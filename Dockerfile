#
# A build container that contains the entire build environment. This means, any
# build tools, node versions, JDKs, etc must be specified here. Including tools
# for pushing built artifacts.
#
FROM debian:jessie

RUN \
    # Fetch all the dependencies first
    apt-get update && \
    apt-get install -y bash-completion \
        build-essential \
        curl \
        git \
        jq \
        netcat \
        python \
        unzip \
        zip \
        zlib1g-dev && \

    # Download and run the bazel installer
    curl -O -L \
          https://github.com/bazelbuild/bazel/releases/download/0.9.0/bazel-0.9.0-installer-linux-x86_64.sh && \
    bash bazel-0.9.0-installer-linux-x86_64.sh && \
    rm bazel-0.9.0-installer-linux-x86_64.sh && \
    bazel version

# Install docker so we can push images.
RUN \
    apt-get install -y apt-transport-https ca-certificates && \
    echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list && \
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 \
        --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    apt-get update && \
    apt-get install -y docker-engine

# Install aws cli for pushing images.
RUN \
    apt-get install -y python \
        python-dev \
        python-pip \
        libyaml-dev && \
    pip install awscli

# Install npm so we can build the web frontend. Don't use the one in the debian
# repositories because it's very old.
RUN \
    curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

# Output to a specific location.
RUN mkdir -p /workspace && \
    echo 'startup --output_base=/workspace/.bazel' > ~/.bazelrc

# We need java to install the rest of the android SDK, bazel uses it's own java.
RUN set -ex && \
    echo 'deb http://deb.debian.org/debian jessie-backports main' \
      > /etc/apt/sources.list.d/jessie-backports.list && \

    apt update -y && \
    apt install -t \
      jessie-backports \
      openjdk-8-jre-headless \
      ca-certificates-java -y

# Install the android SDK
ENV ANDROID_HOME /usr/local/android-sdk
RUN \
    mkdir -p $ANDROID_HOME && \

    # Grab the SDK tools
    curl --location -O https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
    unzip sdk-tools-linux-4333796.zip -d $ANDROID_HOME && \
    rm sdk-tools-linux-4333796.zip && \
    mkdir $ANDROID_HOME/licenses && \

    # Accept all licenses
    yes | $ANDROID_HOME/tools/bin/sdkmanager --licenses && \

    # Install build tools and other components necessary for building. The build
    # tools version must match the WORKSPACE file.
    $ANDROID_HOME/tools/bin/sdkmanager --verbose "tools" "platform-tools" && \
    $ANDROID_HOME/tools/bin/sdkmanager --verbose "build-tools;26.0.1" && \
    $ANDROID_HOME/tools/bin/sdkmanager --verbose "platforms;android-25" "platforms;android-23" && \
    $ANDROID_HOME/tools/bin/sdkmanager --verbose "extras;android;m2repository" "extras;google;m2repository"

WORKDIR /usr/local/src/goodbox_portal
