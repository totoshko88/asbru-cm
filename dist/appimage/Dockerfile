# This Dockerfile should be ran from the project's root directory as context path.

FROM alpine:3.22.1 AS base

WORKDIR /

# Checkout application here
FROM base AS checkout
COPY . /opt/asbru-cm
RUN rm -rf /opt/asbru-cm/.git /opt/asbru-cm/.github /opt/asbru-cm/doc /opt/asbru-cm/scripts

# Common dependencies for both building and running the application
FROM base AS common
RUN apk --no-cache add \
    # Perls
    perl perl-socket6 perl-yaml perl-crypt-cbc perl-glib perl-crypt-rijndael perl-xml-parser perl-io-tty perl-hash-merge-simple \
    # Libs
    libffi pango gtk+3.0 libcanberra-gtk3 gdk-pixbuf librsvg libwnck3 libx11 libxt libxtst dbus-x11 libuuid gobject-introspection \
    # Binaries (with libs maybe)
    busybox-extras openssl openssh-client lftp vte3 expect bash ca-certificates \
    # Fonts
    ttf-dejavu \
    # Icons
    adwaita-icon-theme \
    # Virtual
    --virtual common-packages-step

# Compiler toolchain and dev libs get installed here
FROM common AS builder
RUN apk --no-cache add \
    # Compiler Toolchain
    gcc g++ musl-dev make \
    # Dev Libs
    perl-dev libx11-dev libffi-dev pango-dev openssl-dev libxt-dev libxtst-dev gobject-introspection-dev \
    # Virtual
    --virtual builder-packages-step

# Pull dependencies here from base image, from cache, to avoid re-pulls during development as much as possible
FROM base AS manual-dependency-puller
RUN apk --no-cache add lftp
RUN cd /tmp && lftp -c "open ftp://ftp.ossp.org; get pkg/lib/uuid/uuid-1.6.2.tar.gz -o ./ossp-uuid-1.6.2.tar.gz"
RUN cd /tmp && wget https://cpan.metacpan.org/authors/id/C/CR/CRAZYDJ/Net-ARP-1.0.11.tgz

# Build manual Perl modules here
FROM builder AS perl-builder
# Pull dependencies from manual puller
COPY --from=manual-dependency-puller /tmp/. /tmp
# Manually compile and install OSSP UUID (no perl package available in APK as of writing)
RUN cd /tmp && tar -zxvf /tmp/ossp-uuid-1.6.2.tar.gz && cd uuid-1.6.2/ && ./configure && make && make install && cd perl && perl Makefile.PL && make && make install && rm -rf ossp-uuid-1.6.2.tar.gz uuid-1.6.2
# Manually compile and install Net::ARP with source patch sed
RUN cd /tmp && tar -zxvf Net-ARP-1.0.11.tgz && cd Net-ARP-1.0.11 \
    && sed -i 's/__THROW//g' arp.h \
    && sed -i '1i #include <unistd.h>' get_mac_linux.c \
    && perl Makefile.PL && make && make install \
    && rm -rf Net-ARP-1.0.11.tgz Net-ARP-1.0.11

# Install Perl modules from CPAN here
FROM perl-builder AS cpan-installer
# Install dependencies from CPAN
RUN apk --no-cache add perl-app-cpanminus --virtual cpanm-installer-packages-step
# Install CPAN modules (prefer latest, skip tests where flaky on Alpine)
RUN cpanm --notest Net::Ping
RUN cpanm --notest Glib::Object::Introspection
RUN cpanm --notest Net::Proxy
RUN cpanm --notest IO::Stty Glib::IO Cairo Cairo::GObject X11::GUITest Crypt::Blowfish Pango Gtk3 Gtk3::SimpleList Expect App::Info::Lib::OSSPUUID Data::UUID
RUN cpanm --notest YAML::XS

# Remove as much build-only dependencies as possible
FROM cpan-installer AS stripped-builder
RUN apk --no-cache del cpanm-installer-packages-step builder-packages-step

FROM common AS merged-buildlibs
# Copy built libs, merging with common libs.
COPY --from=stripped-builder /lib/. /lib/
COPY --from=stripped-builder /usr/lib/. /usr/lib/
COPY --from=stripped-builder /usr/local/lib/. /usr/local/lib/
COPY --from=stripped-builder /usr/local/share/. /usr/local/share/
COPY --from=stripped-builder /usr/share/. /usr/share/
COPY --from=stripped-builder /etc/. /etc/

FROM common AS appimage-tools
# Install needed tools; use full wget for TLS and features
RUN apk add --no-cache wget fuse file appstream-glib dos2unix patchelf

RUN wget -O appimagetool-x86_64.AppImage "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" && \
    chmod +x "appimagetool-x86_64.AppImage"

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub

RUN wget -O glibc.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk" && \
    apk add glibc.apk

RUN wget -O glibc-bin.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk" && \
    apk add glibc-bin.apk || true

RUN wget -O glibc-i18n.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-i18n-2.35-r1.apk" && \
    apk add glibc-i18n.apk || true

RUN /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8 || true

#RUN apk add gcompat

FROM appimage-tools AS appimage-assembler

# Create appimage dir
RUN mkdir -p /var/appimage-dir

# Copy built libs.
COPY --from=merged-buildlibs /lib/. /var/appimage-dir/lib/
COPY --from=merged-buildlibs /usr/lib/. /var/appimage-dir/usr/lib/
COPY --from=merged-buildlibs /usr/local/lib/. /var/appimage-dir/usr/local/lib/
COPY --from=merged-buildlibs /usr/local/share/. /var/appimage-dir/usr/local/share/
COPY --from=merged-buildlibs /usr/share/. /var/appimage-dir/usr/share/
COPY --from=merged-buildlibs /etc/xdg/. /var/appimage-dir/etc/xdg/

# Copy Bins
COPY --from=merged-buildlibs /usr/bin/. /var/appimage-dir/usr/bin

# Copy tree checkout
COPY --from=checkout /opt/asbru-cm/. /var/appimage-dir/opt/asbru-cm/
