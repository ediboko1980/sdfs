FROM sdfs-base:3.10.9 AS builder

LABEL email=samsilverberg@google.com
LABEL author="Sam Silverberg"

COPY pom.xml /sdfs-build/
COPY src /sdfs-build/src/
COPY install-packages /sdfs-build/install-packages/
WORKDIR "/sdfs-build"
RUN wget https://cdn.azul.com/zulu/bin/zulu11.35.13-ca-jdk11.0.5-linux_x64.tar.gz && \
    rm -rf install-packages/deb/usr/share/sdfs/bin/jre && \
    tar -xzvf zulu11.35.13-ca-jdk11.0.5-linux_x64.tar.gz && \
    mkdir -p install-packages/deb/usr/share/sdfs/bin/ && \
    cp -rf zulu11.35.13-ca-jdk11.0.5-linux_x64 install-packages/deb/usr/share/sdfs/bin/jre

ENV VERSION=3.10.9
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
ENV DEBFILE="sdfs_${VERSION}_amd64.deb"
RUN echo $DEBFILE
WORKDIR "/sdfs-build/install-packages/"
RUN rm -rf deb/usr/share/sdfs/lib/*
WORKDIR "/sdfs-build/"
RUN mvn package && \
    cp target/lib/b2-2.1.2.jar install-packages/deb/usr/share/sdfs/lib/  && \
    cp target/lib/google-cloud-storage-2.1.2.jar install-packages/deb/usr/share/sdfs/lib/ && \
    cp target/sdfs-${VERSION}-jar-with-dependencies.jar install-packages/deb/usr/share/sdfs/lib/sdfs.jar
WORKDIR "/sdfs-build/install-packages/"
RUN rm -rf *.deb *.rpm && \
    cp DEBIAN/libfuse.so.2 deb/usr/share/sdfs/bin/ && \
    cp DEBIAN/libulockmgr.so.1 deb/usr/share/sdfs/bin/ && \
    cp DEBIAN/libjavafs.so deb/usr/share/sdfs/bin/ && \
    cp ../src/readme.txt deb/usr/share/sdfs/ && \
    fpm -s dir -t deb -n sdfs -v $VERSION -C deb/ -d fuse --url http://www.opendedup.org -d libxml2 -d libxml2-utils -m sam.silverberg@gmail.com --vendor datishsystems --description "SDFS is an inline deduplication based filesystem" && \
    cp RHEL/libfuse.so.2 deb/usr/share/sdfs/bin/ && \
    cp RHEL/libulockmgr.so.1 deb/usr/share/sdfs/bin/ && \
    cp RHEL/libjavafs.so deb/usr/share/sdfs/bin/ && \
    fpm -s dir -t rpm -n sdfs -v $VERSION -C deb/ -d fuse --url http://www.opendedup.org -d libxml2 -m sam.silverberg@gmail.com --vendor datishsystems --description "SDFS is an inline deduplication based filesystem" 
WORKDIR "/sdfs-build/install-packages/"
RUN echo "tar cvf - sdfs_${VERSION}_amd64.deb sdfs-${VERSION}-1.x86_64.rpm" > export_data.sh && \
    chmod 700 export_data.sh
ENTRYPOINT tar cvf - sdfs_${VERSION}_amd64.deb sdfs-${VERSION}-1.x86_64.rpm

FROM ubuntu:18.04
ENV VERSION=3.10.9
LABEL email=samsilverberg@google.com
LABEL author="Sam Silverberg"
RUN apt update && apt upgrade -y && apt install -y \
		openjdk-11-jdk \
        maven \
        libfuse2 \
        ssh \
        openssh-server \
        jsvc \
        libxml2 \
        ruby-dev \
        build-essential \
        libxml2-utils \
        fuse
WORKDIR "/tmp"
COPY --from=0 /sdfs-build/install-packages/sdfs_${VERSION}_amd64.deb .
RUN dpkg -i sdfs_${VERSION}_amd64.deb && \
    rm sdfs_${VERSION}_amd64.deb
COPY --from=0 /sdfs-build/install-packages/docker_run.sh /usr/share/sdfs/docker_run.sh

RUN chmod 700 /usr/share/sdfs/docker_run.sh
ENV DOCKER_DETATCH="-nodetach"
ENV CAPACITY=1TB
CMD ["/usr/share/sdfs/docker_run.sh"]


