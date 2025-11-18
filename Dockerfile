FROM zonemaster/cli:local AS build

ARG version

USER root

RUN apk add --no-cache \
	make \
	curl \
	gcc \
	perl-dev \
	musl-dev \
	perl-app-cpanminus

RUN apk add --no-cache \
	jq \
	perl-class-method-modifiers \
	perl-config-inifiles \
	perl-dbd-sqlite \
	perl-dbi \
	perl-file-share \
	perl-file-slurp \
	perl-html-parser \
	perl-http-parser-xs \
	perl-mojolicious \
	perl-io-stringy \
	perl-log-any \
	perl-log-dispatch \
	perl-moose \
	perl-parallel-forkmanager \
	perl-plack \
	perl-role-tiny \
	perl-test-nowarnings \
	perl-test-differences \
	perl-test-exception \
	perl-try-tiny \
	perl-doc

# for METRIC 
RUN cpanm --notest --no-wget --from https://cpan.metacpan.org/ \
	Net::Statsd 

COPY ./Zonemaster-Backend-${version}.tar.gz ./Zonemaster-Backend-${version}.tar.gz

RUN cpanm --notest --no-wget --from https://cpan.metacpan.org \
    ./Zonemaster-Backend-${version}.tar.gz


FROM zonemaster/cli:local
USER root

COPY --from=build /usr/local/share/perl5 /usr/local/share/perl5
COPY --from=build /usr/local/bin/ /usr/local/bin/
COPY --from=build /usr/lib/perl5 /usr/lib/perl5

RUN apk add --no-cache \
	jq \
	perl-config-inifiles \
	perl-mojolicious \
	perl-moose \
	perl-dbi \
	perl-dbd-sqlite \
	perl-plack \
	perl-parallel-forkmanager

# Create zonemaster user and group
RUN addgroup -S zonemaster
RUN adduser  -S zonemaster -G zonemaster

RUN cd `perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")'` && \
	install -v -m 755 -d /etc/zonemaster && \
	install -v -m 775 -g zonemaster -d /var/log/zonemaster && \
	install -v -m 640 -g zonemaster ./backend_config.ini /etc/zonemaster/


# Init SQLite database
RUN install -v -m 755 -o zonemaster -g zonemaster -d /var/lib/zonemaster
USER zonemaster
RUN  $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')/create_db.pl
USER zonemaster
COPY zonemaster_launch /usr/local/bin

USER root
ARG S6_OVERLAY_VERSION=3.2.1.0

# Install S6
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz


# RPCAPI service
RUN mkdir /etc/s6-overlay/s6-rc.d/rpcapi
RUN echo "longrun" > /etc/s6-overlay/s6-rc.d/rpcapi/type
RUN echo "#!/command/with-contenv sh" > /etc/s6-overlay/s6-rc.d/rpcapi/run
RUN echo "zonemaster_launch rpcapi" >> /etc/s6-overlay/s6-rc.d/rpcapi/run

# TESTAGENT sevice
RUN mkdir /etc/s6-overlay/s6-rc.d/testagent
RUN echo "longrun" > /etc/s6-overlay/s6-rc.d/testagent/type
RUN echo "#!/command/with-contenv sh" > /etc/s6-overlay/s6-rc.d/testagent/run
RUN echo "zonemaster_launch testagent" >> /etc/s6-overlay/s6-rc.d/testagent/run

RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/rpcapi
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/testagent

ENTRYPOINT ["/usr/local/bin/zonemaster_launch"]
