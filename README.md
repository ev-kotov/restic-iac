# restic-iac

A rootless IaC of [restic](https://github.com/restic/restic) using [Podman](https://github.com/podman-container-tools/podman) (version earlier then 5).

The project uses `.container` files instead of grouping via `.pod`, as pod generation using `.pod` is not supported in Podman 4.9.x - resulting in an `unsupported key 'Pod' in group 'Container'` error (confirmed in issue [#21371](https://github.com/podman-container-tools/podman/issues/21371)). Full support for `.pod` was added in Podman 5.0.0.

## Requirments

- [podman-sh-lib](https://github.com/ev-kotov/podman-sh-lib)
- [notify-sh-lib](https://github.com/ev-kotov/notify-sh-lib)

## Run

```bash
sudo dnf install restic
sudo mkdir -p /etc/restic
sudo blkid
openssl rand -base64 32
sudo sh -c 'echo "your_password" > /etc/restic/pass'
sudo chmod 600 /etc/restic/pass
sudo chown root:root /etc/restic/pass
chmod +x deploy.sh
sh deploy.sh
```

## Update

Change iac and execute:

```bash
sh deploy.sh
```
