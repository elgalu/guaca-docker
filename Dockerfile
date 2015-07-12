###################################################
# Selenium standalone docker for Chrome & Firefox #
###################################################
#== Ubuntu wily is 15.10.x, i.e. FROM ubuntu:15.10
# search for more at https://registry.hub.docker.com/_/ubuntu/tags/manage/
FROM ubuntu:wily-20150708
ENV UBUNTU_FLAVOR wily

#== Ubuntu vivid is 15.04.x, i.e. FROM ubuntu:15.04
# search for more at https://registry.hub.docker.com/_/ubuntu/tags/manage/
#                    http://cloud-images.ubuntu.com/releases/15.04/
# FROM ubuntu:vivid-20150611
# ENV UBUNTU_FLAVOR vivid

#== Ubuntu trusty is 14.04.x, i.e. FROM ubuntu:14.04
#== Could also use ubuntu:latest but for the sake I replicating an precise env...
# search for more at https://registry.hub.docker.com/_/ubuntu/tags/manage/
#                    http://cloud-images.ubuntu.com/releases/14.04/
# FROM ubuntu:14.04.2
# ENV UBUNTU_FLAVOR trusty

#== Ubuntu precise is 12.04.x, i.e. FROM ubuntu:12.04
#== Could also use ubuntu:latest but for the sake I replicating an precise env...
# search for more at https://registry.hub.docker.com/_/ubuntu/tags/manage/
#                    http://cloud-images.ubuntu.com/releases/12.04/
# FROM ubuntu:precise-20150612
# ENV UBUNTU_FLAVOR precise

#== Ubuntu flavors - common
RUN  echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_FLAVOR} main universe\n" > /etc/apt/sources.list \
  && echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_FLAVOR}-updates main universe\n" >> /etc/apt/sources.list

MAINTAINER Leo Gallucci <elgalu3@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

#========================
# Miscellaneous packages
#========================
# netcat-openbsd - nc — arbitrary TCP and UDP connections and listens
# net-tools - arp, hostname, ifconfig, netstat, route, plipconfig, iptunnel
# iputils-ping - ping, ping6 - send ICMP ECHO_REQUEST to network hosts
# apt-utils - commandline utilities related to package management with APT
# wget - The non-interactive network downloader
# curl - transfer a URL
# bc - An arbitrary precision calculator language
# pwgen: generates random, meaningless but pronounceable passwords
# ts from moreutils will prepend a timestamp to every line of input you give it
# grc is a terminal colorizer that works nice with tail https://github.com/garabik/grc
RUN apt-get update -qqy \
  && apt-get -qqy install \
    apt-utils \
    sudo \
    net-tools \
    telnet \
    jq \
    netcat-openbsd \
    iputils-ping \
    unzip \
    wget \
    curl \
    pwgen \
    bc \
    grc \
    moreutils \
  && mkdir -p /var/log/guaca \
  && mkdir -p /var/run/guaca \
  && rm -rf /var/lib/apt/lists/*

#==============================
# Locale and encoding settings
#==============================
# TODO: Allow to change instance language OS and Browser level
#  see if this helps: https://github.com/rogaha/docker-desktop/blob/68d7ca9df47b98f3ba58184c951e49098024dc24/Dockerfile#L57
ENV LANG_WHICH en
ENV LANG_WHERE US
ENV ENCODING UTF-8
ENV LANGUAGE ${LANG_WHICH}_${LANG_WHERE}.${ENCODING}
ENV LANG ${LANGUAGE}
RUN locale-gen ${LANGUAGE} \
  && dpkg-reconfigure --frontend noninteractive locales \
  && apt-get update -qqy \
  && apt-get -qqy install \
    language-pack-en \
  && rm -rf /var/lib/apt/lists/*

#===================
# Timezone settings
#===================
# Full list at http://en.wikipedia.org/wiki/List_of_tz_database_time_zones
#  e.g. "US/Pacific" for Los Angeles, California, USA
# ENV TZ "US/Pacific"
ENV TZ "Europe/Berlin"
# Apply TimeZone
RUN echo $TZ | tee /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

#==============================
# Java7 - OpenJDK JRE headless
# Minimal runtime used for executing non GUI Java programs
#==============================
# Regarding urandom see
#  http://stackoverflow.com/q/26021181/511069
#  https://github.com/SeleniumHQ/docker-selenium/issues/14#issuecomment-67414070
# RUN apt-get update -qqy \
#   && apt-get -qqy install \
#     openjdk-7-jre-headless \
#   && sed -i 's/securerandom.source=file:\/dev\/urandom/securerandom.source=file:\/dev\/.\/urandom/g' \
#        /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security/java.security \
#   && sed -i 's/securerandom.source=file:\/dev\/random/securerandom.source=file:\/dev\/.\/urandom/g' \
#        /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security/java.security \
#   && rm -rf /var/lib/apt/lists/*

#==============================
# Java8 - OpenJDK JRE headless
# Minimal runtime used for executing non GUI Java programs
#==============================
# Regarding urandom see
#  http://stackoverflow.com/q/26021181/511069
#  https://github.com/SeleniumHQ/docker-selenium/issues/14#issuecomment-67414070
# RUN apt-get update -qqy \
#   && apt-get -qqy install \
#     openjdk-8-jre-headless \
#   && sed -i 's/securerandom.source=file:\/dev\/urandom/securerandom.source=file:\/dev\/.\/urandom/g' \
#        /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/java.security \
#   && sed -i 's/securerandom.source=file:\/dev\/random/securerandom.source=file:\/dev\/.\/urandom/g' \
#        /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/java.security \
#   && rm -rf /var/lib/apt/lists/*

#==================
# Java8 - Oracle
#==================
# Regarding urandom see
#  http://stackoverflow.com/q/26021181/511069
#  https://github.com/SeleniumHQ/docker-selenium/issues/14#issuecomment-67414070
RUN apt-get update -qqy \
  && apt-get -qqy install \
    software-properties-common \
  && echo debconf shared/accepted-oracle-license-v1-1 \
      select true | debconf-set-selections \
  && echo debconf shared/accepted-oracle-license-v1-1 \
      seen true | debconf-set-selections \
  && add-apt-repository ppa:webupd8team/java \
  && apt-get update -qqy \
  && apt-get -qqy install \
    oracle-java8-installer \
  && sed -i 's/securerandom.source=file:\/dev\/urandom/securerandom.source=file:\/dev\/.\/urandom/g' \
       /usr/lib/jvm/java-8-oracle/jre/lib/security/java.security \
  && sed -i 's/securerandom.source=file:\/dev\/random/securerandom.source=file:\/dev\/.\/urandom/g' \
       /usr/lib/jvm/java-8-oracle/jre/lib/security/java.security \
  && rm -rf /var/lib/apt/lists/*

#========================
# Guacamole dependencies
#========================
RUN apt-get update -qqy \
  && apt-get -qqy install \
    gcc make \
    libcairo2-dev libpng12-dev libossp-uuid-dev \
    libssh2-1 libssh-dev libssh2-1-dev \
    libssl-dev libssl0.9.8 \
    libpango1.0-dev \
    autoconf libvncserver-dev \
  && rm -rf /var/lib/apt/lists/*

#=====================
# Use Normal User now
#=====================
USER ${NORMAL_USER}

#======================
# Tomcat for Guacamole
#======================
ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.0.23
ENV TOMCAT_TGZ_URL https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
# ENV CATALINA_HOME /usr/local/tomcat
ENV CATALINA_HOME ${HOME}/tomcat
# WORKDIR ${CATALINA_HOME}
# see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
RUN mkdir -p ${CATALINA_HOME} \
  && cd ${CATALINA_HOME} \
  && gpg --keyserver pool.sks-keyservers.net --recv-keys \
       05AB33110949707C93A279E3D3EFE6B686867BA6 \
       07E48665A34DCAFAE522E5E6266191C37C037D42 \
       47309207D818FFD8DCD3F83F1931D684307A10A5 \
       541FBE7D8F78B25E055DDEE13C370389288584E7 \
       61B832AC2F1C5A90F0F9B00A1C506407564C17A3 \
       79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED \
       9BA44C2621385CB966EBA586F72C284D731FABEE \
       A27677289986DB50844682F8ACB77FC2E86E29AC \
       A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 \
       DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 \
       F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE \
       F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23 \
  && wget --no-verbose "$TOMCAT_TGZ_URL" -O tomcat.tar.gz \
  && wget --no-verbose "$TOMCAT_TGZ_URL.asc" -O tomcat.tar.gz.asc \
  && gpg --verify tomcat.tar.gz.asc \
  && tar -xvf tomcat.tar.gz --strip-components=1 > /dev/null \
  && rm bin/*.bat \
  && rm tomcat.tar.gz*

#===================
# Guacamole web-app
#===================
# https://github.com/glyptodon/guacamole-server/releases
ENV GUACAMOLE_VERSION 0.9.7
ENV GUACAMOLE_WAR_SHA1 69b7566092cf13076bddc331772a5b31dba45fb5
ENV GUACAMOLE_HOME ${HOME}/guacamole
RUN mkdir -p ${GUACAMOLE_HOME}
# http://guac-dev.org/doc/gug/configuring-guacamole.html
COPY guacamole_home/* ${GUACAMOLE_HOME}/
# Disable Tomcat's manager application.
# e.g. to customize JVM's max heap size 256MB: -e JAVA_OPTS="-Xmx256m"
RUN cd ${CATALINA_HOME} && rm -rf webapps/* \
  && echo "${GUACAMOLE_WAR_SHA1}  ROOT.war" > webapps/ROOT.war.sha1 \
  && wget --no-verbose -O webapps/ROOT.war "http://sourceforge.net/projects/guacamole/files/current/binary/guacamole-${GUACAMOLE_VERSION}.war/download" \
  && cd webapps && sha1sum -c --quiet ROOT.war.sha1 && cd .. \
  && echo "export CATALINA_OPTS=\"${JAVA_OPTS}\"" >> bin/setenv.sh
#========================
# Guacamole server guacd
#========================
ENV GUACAMOLE_SERVER_SHA1 43883eb86d70b68da723a2d57d50d866a8af5f16
RUN cd /tmp \
  && echo ${GUACAMOLE_SERVER_SHA1}  guacamole-server.tar.gz > guacamole-server.tar.gz.sha1 \
  && wget --no-verbose -O guacamole-server.tar.gz "http://sourceforge.net/projects/guacamole/files/current/source/guacamole-server-${GUACAMOLE_VERSION}.tar.gz/download" \
  && sha1sum -c --quiet guacamole-server.tar.gz.sha1 \
  && tar xzf guacamole-server.tar.gz \
  && rm guacamole-server.tar.gz* \
  && cd guacamole-server-${GUACAMOLE_VERSION} \
  && ./configure \
  && make \
  && sudo make install \
  && sudo ldconfig

#========================================================================
# Some configuration options that can be customized at container runtime
#========================================================================
ENV BIN_UTILS /bin-utils
ENV PATH ${PATH}:${BIN_UTILS}:${CATALINA_HOME}/bin
ENV GUACAMOLE_SERVER_PORT 4822
# All tomcat ports can be customized if necessary
ENV TOMCAT_PORT 8484
ENV TOMCAT_SHUTDOWN_PORT 8485
ENV TOMCAT_AJP_PORT 8489
ENV TOMCAT_REDIRECT_PORT 8483
# Logs
ENV CATALINA_LOG "/var/log/guaca/tomcat-server.log"
ENV GUACD_LOG "/var/log/guaca/guacd-server.log"

#================================
# Expose Container's Directories
#================================
VOLUME /var/log/guaca

EXPOSE ${TOMCAT_PORT}

#===================
# CMD or ENTRYPOINT
#===================
CMD ["entry.sh"]
