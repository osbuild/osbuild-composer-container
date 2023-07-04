# OSBuild Composer in a container

This repository periodically builds container images with osbuild-composer inside. This image is particularly useful in CI environments for building OS images.

> **Warning!**
> 
> Building an image using osbuild-composer within a container can potentially yield unexpected results. Therefore, please note that this repository should be considered **experimental**, and support is provided on a **best-effort basis**.

## Variants

The container images in this repository are refreshed nightly and are available for multiple versions of Fedora Linux and CentOS Stream. Additionally, there are specific images that include the latest versions of osbuild and osbuild-composer from their respective COPR repositories. Additionally, there are specific images that include the latest versions of [osbuild](https://copr.fedorainfracloud.org/coprs/g/osbuild/osbuild/) and [osbuild-composer](https://copr.fedorainfracloud.org/coprs/g/osbuild/osbuild-composer/ from their respective COPR repositories.

The full tag for the images follows the following format:

```
$DISTRIBUTION-$VERSION(-copr)?
```

Here, `$DISTRIBUTION` can be either `fedora` or `centos-stream`. The valid `$VERSION` values for Fedora are currently `37` and `38`. For CentOS Stream, it's possible to use either `8` or `9`. The optional `-copr` suffix indicates that these images include the latest upstream versions of `osbuild` and `osbuild-composer` from COPR.

If a rolling tag isn't suitable for your use case, this project also provides non-moving tags with the date of the container build encoded in ISO 8601 format.

```
$DISTRIBUTION-$VERSION(-copr)?-$(date --iso-8601=date)
```

These tags allow you to pinpoint specific container builds based on the date they were created.

## Internals

The container images have `osbuild-composer` and `weldr-client` installed inside, orchestrated using `systemd` as the container's `CMD`. To ensure that the image building process has the necessary system privileges, the container must be started with the `--privileged` flag.

In addition to the standard setup, the image includes the following additions:

- The Weldr API socket is available at both the default location `/run/weldr/api.socket` and an additional location `/builds/weldr-api.socket`. The availability of the socket at `/builds/weldr-api.socket` is necessary for proper functioning of the container in GitLab CI. The `weldr-client` can make use of this socket by specifying the path with the `composer-cli --socket /builds/weldr-api.socket` command.
- The systemd journal is accessible as a text file at `/builds/osbuild-composer-journal.txt`. This provides convenient access to the container's systemd journal logs.

## Examples

The following sections explain how to use the container in both GitHub Actions and GitLab CI.

Both examples require a blueprint file named `my-image.toml` with a name `my-image` located in the root directory of the repository. The blueprint is used to build a `qcow2` image suitable for KVM virtualization (libvirt, OpenStack). Finally, the resulting image is uploaded to an artifact storage.

Here is an example of such a blueprint (remember to save it as `my-image.toml` in the repository's root directory):

```
name = "my-image"
packages = [{name = "nginx"}]
```

### GitHub Actions

```yaml
name: Build images

on:
  push:

jobs:
  build:
    runs-on: ubuntu-22.04
    services:
      osbuild-composer:
        image: ghcr.io/osbuild/osbuild-composer-container:centos-stream-9
        volumes:
          - /builds:/builds
        options: --privileged
    container:
      image: ghcr.io/osbuild/osbuild-composer-container:centos-stream-9
      volumes:
        - /builds:/builds
    steps:
      - name: Checkout repo
        uses: actions/checkout@v3

      - name: Run the build
        shell: bash
        run: |
          sleep 5
          tail --follow --lines +1 "/builds/osbuild-composer-journal.txt" &
          composer-cli() { /usr/bin/composer-cli --socket /builds/weldr-api.socket "$@"; }
          composer-cli blueprints push my-image.toml
          compose_id=$(composer-cli --json compose start my-image qcow2 | jq -r ".[].body.build_id")
          while [[ $(composer-cli --json compose info "${compose_id}" | jq -r ".[].body.queue_status") =~ RUNNING|WAITING ]]; do sleep 15; done
          
          # check whether the build succeeded
          [[ $(composer-cli --json compose info "${compose_id}" | jq -r ".[].body.queue_status") =~ FINISHED ]] || exit 1
          
          composer-cli compose image "${compose_id}" --filename image.qcow2

      - name: Upload image artifacts
        uses: actions/upload-artifact@v3
        with:
          name: image.qcow2
          path: image.qcow2
```

### GitLab CI

```yaml
build:
  image: ghcr.io/osbuild/osbuild-composer-container:centos-stream-9
  services:
    - ghcr.io/osbuild/osbuild-composer-container:centos-stream-9
  before_script: |
    sleep 5
    tail --follow --lines +1 "/builds/osbuild-composer-journal.txt" &
    composer-cli() { /usr/bin/composer-cli --socket /builds/weldr-api.socket "$@"; }
  script: |
    composer-cli blueprints push my-image.toml
    compose_id=$(composer-cli --json compose start my-image qcow2 | jq -r ".[].body.build_id")
    while [[ $(composer-cli --json compose info "${compose_id}" | jq -r ".[].body.queue_status") =~ RUNNING|WAITING ]]; do sleep 15; done
    
    # check whether the build succeeded
    [[ $(composer-cli --json compose info "${compose_id}" | jq -r ".[].body.queue_status") =~ FINISHED ]] || exit 1
    
    composer-cli compose image "${compose_id}" --filename image.qcow2
    
  artifacts:
    - image.qcow2


```

## Acknowledgements

Big thanks to Major Hayden and Michael Hofmann for their initial investigation into running osbuild-composer in containerized CI environments!
