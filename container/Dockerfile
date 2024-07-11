FROM registry.opensuse.org/opensuse/leap:15.6

COPY fcgiwrap.service /etc/systemd/system/fcgiwrap.service
COPY fcgiwrap.socket /etc/systemd/system/fcgiwrap.socket
RUN zypper ar -f obs://home:bhwachter/openSUSE_Leap_15.6 bhwachter &&\
    zypper ar -f obs://home:bhwachter:server/openSUSE_Leap_15.6 bhwachter_server && \
     zypper --gpg-auto-import-keys ref

RUN zypper -n in git vim less iproute2 strace nmap tcpdump bind-utils fcgiwrap fcgiwrap-nginx mariadb-client nginx perl-CDB-TinyCDB perl-CGI perl-DBD-Pg perl-DBD-SQLite perl-DBD-mysql perl-File-Type perl-GD perl-Module-Path perl-Syntax-SourceHighlight perl-Text-Markdown-Hoedown perl-Tie-RegexpHash perl-TimeDate perl-URI perl-XML-Atom perl-XML-RSS perl-YAML-LibYAML perl-libintl-perl source-highlight perl-File-Touch

COPY nginx /etc/nginx
COPY awfulcms.config /srv/web/.awfulcms/config
COPY awfulcms.cgi /srv/web/public_html/awfulcms.cgi
RUN groupadd -g 1000 awfulcms
RUN useradd -m -u 1000 -g 1000 -d /srv/web awfulcms
RUN systemctl enable nginx.service
RUN systemctl enable fcgiwrap.service
RUN sed -i 's/^FCGI_WORKERS.*/FCGI_WORKERS="50"/' /etc/sysconfig/fcgiwrap
RUN mkdir -p /srv/web/cache; chown -R awfulcms: /srv/web/cache
RUN mkdir -p /srv/web/rwroot/blog; chown -R awfulcms: /srv/web/rwroot/blog
RUN mkdir -p /srv/web/public_html; chown -R awfulcms: /srv/web/public_html
RUN touch /srv/web/cgi-log; chown awfulcms: /srv/web/cgi-log
RUN git clone https://github.com/bwachter/awfulcms.git /srv/web/awfulcms

CMD [ "/usr/lib/systemd/systemd" ]
