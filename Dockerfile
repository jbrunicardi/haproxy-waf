FROM jbrunicardi/docker-centos-supervisor:latest

# take a look at http://www.lua.org/download.html for
# newer version

ENV HAPROXY_MAJOR=1.8 \
    HAPROXY_VERSION=1.8.x \
    HAPROXY_MD5=ed84c80cb97852d2aa3161ed16c48a1c \
    LUA_VERSION=5.3.4 \
    LUA_URL=http://www.lua.org/ftp/lua-5.3.4.tar.gz \
    LUA_MD5=53a9c68bcc0eda58bdc2095ad5cdfc63 \
    MODSEC_URL=https://www.modsecurity.org/tarball/2.9.1/modsecurity-2.9.1.tar.gz \
    MODSEC_SHA256=958cc5a7a7430f93fac0fd6f8b9aa92fc1801efce0cda797d6029d44080a9b24 
#    MODSEC_CRS_URL=https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0.0.tar.gz \
#    CRS_FILE=owasp-modsecurity-crs-v3.0.0.tar.gz

# RUN cat /etc/redhat-release
# RUN yum provides "*lib*/libc.a"

# due to the fact that the patches are now part of
# haproxy, I don't need to copy the patches into the
# build image

# to be able to add the patches in containerfiles dir
# COPY containerfiles /

# cyrus-sasl must be added to not remove systemd 8-O strange.

COPY filebeat-1.2.3-x86_64.rpm /tmp/filebeat-1.2.3-x86_64.rpm

RUN set -x \
  && export buildDeps='pcre-devel openssl-devel gcc make zlib-devel readline-devel openssl patch git apr-devel apr-util-devel libevent-devel libxml2-devel libcurl-devel httpd-devel pcre-devel yajl-devel' \
  && yum -y install pcre openssl-libs zlib bind-utils curl iproute tar strace libevent libxml2 libcurl apr apr-util yajl cyrus-sasl ${buildDeps} \
  && curl -sSL ${LUA_URL} -o lua-${LUA_VERSION}.tar.gz \
  && curl -sSL ${MODSEC_URL} -o modsecurity-2.9.1.tar.gz \
#  && curl -sSL ${MODSEC_CRS_URL} -o ${CRS_FILE} \
  && echo "${LUA_MD5} lua-${LUA_VERSION}.tar.gz" | md5sum -c \
  && echo "${MODSEC_SHA256} modsecurity-2.9.1.tar.gz" | sha256sum -c \
  && mkdir -p /usr/src/lua /data \
  && tar -xzf lua-${LUA_VERSION}.tar.gz -C /usr/src/lua --strip-components=1 \
#  && tar -xzf  ${CRS_FILE} -C /data \
  && rm lua-${LUA_VERSION}.tar.gz \
  && make -C /usr/src/lua linux test install \
  && tar xfvz modsecurity-2.9.1.tar.gz \
  && cd modsecurity-2.9.1 \
  && ./configure \
      --prefix=$PWD/INSTALL \
      --disable-apache2-module \
      --enable-standalone-module \
      --enable-pcre-study \
      --without-lua \
      --enable-pcre-jit \
  && make -C standalone install \
  && mkdir -p $PWD/INSTALL/include \
  && cp standalone/*.h $PWD/INSTALL/include \
  && cp apache2/*.h $PWD/INSTALL/include \
  && cd /usr/src \
  && git clone http://git.haproxy.org/git/haproxy.git/ \
  && make -C /usr/src/haproxy \
	TARGET=linux2628 \
	USE_PCRE=1 \
	USE_OPENSSL=1 \
	USE_ZLIB=1 \
        USE_LINUX_SPLICE=1 \
        USE_TFO=1 \
        USE_PCRE_JIT=1 \
        USE_LUA=1 \
	all \
	install-bin \
  && cd /usr/src/haproxy/contrib/modsecurity \
  && make MODSEC_INC=/modsecurity-2.9.1/INSTALL/include \
      MODSEC_LIB=/modsecurity-2.9.1/INSTALL/lib \
      APACHE2_INC=/usr/include/httpd \
      APR_INC=/usr/include/apr-1 \
  && make install \
  && mkdir -p /usr/local/etc/haproxy \
  && mkdir -p /usr/local/etc/haproxy/ssl \
  && mkdir -p /usr/local/etc/haproxy/ssl/cas \
  && mkdir -p /usr/local/etc/haproxy/ssl/crts \
  && mkdir -p /usr/local/etc/modsecurity \
  && mkdir -p /usr/local/etc/modsecurity/owasp-modsecurity-crs \
  && cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
  && rm -rf /usr/src/haproxy /usr/src/lua /*tar.gz \
  && yum install -y libmhash-devel \
  && yum install -y vixie-cron crontabs \
  && yum install -y logrotate \  
  && yum localinstall -y /tmp/filebeat-1.2.3-x86_64.rpm \
  && rm -f /tmp/filebeat-1.2.3-x86_64.rpm \
  && yum -y autoremove $buildDeps \
  && yum -y clean all

#         && openssl dhparam -out /usr/local/etc/haproxy/ssl/dh-param_4096 4096 \

ENV DEBUG	-d
ENV LOGSTASH_HOST   127.0.0.1:5044

ADD container-files /