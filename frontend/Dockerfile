FROM openquantumsafe/nginx:latest

USER root

RUN apk add --no-cache \
    git \
    cmake \
    build-base \
    pkgconfig \
    zlib-dev \
    linux-headers \
    perl \
    bash \
    util-linux-dev \
    musl-dev \
    tcpdump

# Source and build OpenSSL (comes with default.so hopefully)
WORKDIR /home
RUN git clone --single-branch --branch openssl-3.0 https://github.com/openssl/openssl.git
RUN cd openssl/ && \
    ./Configure linux-x86_64 --prefix=/usr/local/ --openssldir=/opt/openssl/.openssl/ssl/ \
    --libdir=/opt/openssl/.openssl/lib64/ \
    enable-fips -DOPENSSL_MODULES_PATH=/opt/openssl/.openssl/lib64/ossl-modules && \
    make -j$(nproc) && \
    make install_sw

#RUN cp -r /opt/openssl/.openssl/lib64/ossl-modules/oqsprovider.so /usr/local/lib64/ossl-modules

WORKDIR /opt/nginx
RUN mkdir certs
RUN rm -rf html/*

COPY index.html html/index.html
COPY nginx.conf conf/nginx.conf
COPY openssl.cnf /opt/openssl/.openssl/ssl/openssl.cnf
# COPY ../certs/cert.pem certs/cert.pem
# COPY ../certs/key.pem certs/key.pem

ENV OPENSSL_MODULES=/opt/openssl/.openssl/lib64/ossl-modules
ENV OPENSSL_CONF=/opt/openssl/.openssl/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/opt/openssl/.openssl/lib64/

# Generate frontend server cert/key pair
RUN openssl req -x509 \
    -new -subj "/CN=localhost" \
    -newkey rsa3072_falcon512 \
    -days 365 \
    -noenc \
    -nodes \
    -provider default \
    -provider oqsprovider \
    -out certs/cert.pem \
    -keyout certs/key.pem

EXPOSE 80
EXPOSE 443
