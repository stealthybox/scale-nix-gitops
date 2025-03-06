# syntax=docker/dockerfile:1.4

FROM mcr.microsoft.com/devcontainers/base:ubuntu

# create and configure some build users for some isolation
RUN sudo groupadd -r nixbld; for n in $(seq 1 30); do sudo useradd -c "Nix build user $n" -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(command -v nologin)" "nixbld$n"; done
# install flox + nix
RUN wget -O flox.deb "https://downloads.flox.dev/by-env/stable/deb/flox-1.3.16.$(uname -p)-linux.deb" \
 && dpkg -i flox.deb \
 && rm flox.deb
RUN rm /etc/nix/nix.conf \
 && echo "build-users-group = nixbld" >> /etc/nix/nix.conf \
 && echo "include flox.conf" >> /etc/nix/nix.conf
  # include your own conf here if you have a nix binary-cache

# install dockerd for root, so that it's already present for the docker setup feature
# we're including the docker client and server directly in the user's flox env
# then we're re-using it for the root user.
# this has a secondery effect of caching all of the user's flox env within the
# docker image.
# when the user starts their environment, everything will cache hit.
# dev containers allows us to run the nix daemon using openrc, so it's okay that
# these folders are being created as root with single-user mode, because the nix
# daemon always writes and reads as root
COPY .flox /root/.flox
ENV SHELL "/usr/bin/bash"
RUN chsh -s "/usr/bin/bash"
RUN flox activate -vvvvv -d /root/
# enable default flox env for root shells
# this is needed so the docker setup feature see that dockerd is already on the PATH
RUN echo 'eval "$(flox activate -d ~ -m run)"' >> /root/.bashrc

USER vscode
# we want the user's active flox environment to be the workspace directory,
# so we'll add that to the vscode user's shell config in `post-create`
