from debian:testing

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y systemd initscripts locales locales-all wget apt-transport-https \
       ruby ruby-bundler ruby-dev rake-compiler build-essential pkg-config libmagickcore-6.q16-dev libssl-dev \
       git-annex \
    && locale-gen en_US.UTF-8 \
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
      /etc/systemd/system/*.wants/* \
      /lib/systemd/system/local-fs.target.wants/* \
      /lib/systemd/system/sockets.target.wants/*udev* \
      /lib/systemd/system/sockets.target.wants/*initctl* \
      /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
      /lib/systemd/system/systemd-update-utmp* \
    && apt-get install -y openssh-server openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && mkdir -p /var/run/sshd \
    && adduser --uid 1000 --disabled-password david \
    && adduser --uid 1002 --disabled-password cheesy \
    && mkdir -p /home/david/.ssh /home/cheesy/.ssh \
    && echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6nfLnzeT4NmXy53/8ZCbvcbgZ496s5+o7ouIAhuNs7jzLBTSdXxJAxdDuX2RYJVL3AmcBkhrg2sL2dMnXrhP7KT/55z1vYFds80a6byWnFUKs/ZJAamEh+FfWkfbMe7MxdWn3qt832Kr6+t2/mxgZA+c0b4hHZuZy7VLw6O2hoLhrudOJV11GdMEebx9vNThj3NMsjtYOdaGiX8FgxpaI5JwahkuhCr/D6qSgu/GbWGuYc9r1O1QUy+lsuV8oe9LQdfT3j7dhLW1EsTNRzhsQJXKpfV0PPrYonNYQsyCoVEhP+2gqlnwEePeKaGYnxNYvqrWnXBs3j6sInwb0Btv/ david@puppet" > /home/david/.ssh/authorized_keys \
    && chown david /home/david/.ssh/authorized_keys \
    && echo "" > /home/cheesy/.ssh/authorized_keys \
    && chown cheesy /home/cheesy/.ssh/authorized_keys \
    && chmod 0600 /home/david/.ssh/authorized_keys /home/cheesy/.ssh/authorized_keys \
    && sed -ri "s/^#?UseDNS .*/UseDNS no/" /etc/ssh/sshd_config \
    && sed -e "/HostKey.*ssh_host_e.*_key/ s/^#*/#/" -ri /etc/ssh/sshd_config

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

VOLUME [ "/sys/fs/cgroup" ]

STOPSIGNAL SIGRTMIN+3

CMD ["sh", "-e", "-c", "cp -av /srv/cheesy.at/secrets/ssh/* /etc/ssh/; echo starting systemd; exec /lib/systemd/systemd"]
