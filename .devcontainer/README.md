# floxtest

This is a devcontainer workspace driven by a single Dockerfile.

The Dockerfile:
- Uses the microsoft ubuntu base for full compatibility with the devcontainer ecosystem
- Uses openRC init from the ubuntu base
- Installs Flox
- Configures Flox's Nix install to use a nixbld group of users
- Sets the root shell to use the repo's flox environment for dockerd
- Caches the repo's flox environment within the image

The devcontainer.json:
- Enables docker-in-docker (ipv6 disabled because codespaces hosts don't support it well for docker+kubernetes)

When the environment is started,
- A full, sandbox capable, multi-user Nix daemon is started with OpenRC
- A kind cluster + registry is started within docker-in-docker
- The repo's flox environment is configured within the user's bashrc to auto-activate

### what's working
- Dependencies can now be managed by running `flox install` or `flox edit`
  the codespace, and then doing `git commit -a "Add <dependency> for <thing>"`.
- `flox upgrade` -> `git commit`
- People updating their dependencies don't immediately need to rebuild containers.
- Anybody who does a `git pull` and opens a terminal will pull the new dependencies
  and stay within their workflow.
- docker-in-docker works
- docker info shows docker extensions like buildx and compose coming from the flox environment
- kind works

### improvements to explore
- Add/generate a separate flox environment, just for the root user's docker install
  instead of reusing the git repo's. sync the docker versions.
  This could be generated using flox's lockfile.
- Disable the apt-based install from docker-in-docker -- it's supposed to skip
  the apt install if `dockerd` is on the path, but the version heuristic may be failing.
  The upstream devcontainer feature doesn't just provide a sensible flag to turn it off.
  It's possible to just copy the init script as an entrypoint and run the configuration script
  as part of the Dockerfile with all of the apt stuff removed.
  This would be great, because Flox's nixpkgs based install of docker is much quicker
  than apt and can be managed with git.
- docker-outside-of-docker is failing mysteriously doing `kind cluster create`.
  Using docker-in-docker works, though.
- Play with not caching the .flox env within the container. Every codespace already
  has a persistent filesystem. It's a trade-off to have to write the nix store to the
  devcontainer inline cache when we are already pulling dependencies from an existing binary cache.
  Pulling packages in post-create.sh (except for docker) might be faster.
- Play with adding an iterative fs cache of `/nix` to the Dockerfile using buildkit
  features. Buildkit doesn't publish cache folders to the final image, but we need
  the nix store to be published, so a nix configuration, some creative usage of hardlinks
  or using `mv` or `cp -a` might be sufficient to be much faster than the network.
  (An fs cache is not applicable if we don't cache the flox env in the container at all.)
- Fix certain Flox bugs like it not liking this Ubuntu containers configuration of
  dash (by name instead of being called `sh`) as the default shell.
- Consider running the kind registry and cluster in two separate flox services.
  This would provide a uniform U/X for managing the infra beside the dev or ops env.
- Consider using `ghcr.io/flox/flox` for the base image -- we might want openrc.
  Maybe `flox services` is also sufficient.
  Devcontainer tooling may have some other interesing dependencies.
- Configure zsh + p10k or fish, managed by Flox, for a fun, nice U/X
- Look for ways to simplify
- Consider other requirements
