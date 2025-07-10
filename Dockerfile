FROM zonemaster/engine:local

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

ARG version

COPY ./Zonemaster-Backend-${version}.tar.gz ./Zonemaster-Backend-${version}.tar.gz

RUN cpanm --notest --no-wget --from https://cpan.metacpan.org/ \
    ./Zonemaster-Backend-${version}.tar.gz

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
