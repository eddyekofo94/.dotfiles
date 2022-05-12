# Set up WSL & Docker Desktop [Full docs](https://docs.docker.com/desktop/windows/wsl/)
Ensure the distribution runs in WSL 2 mode. WSL can run distributions in both v1 or v2 mode.

To check the WSL mode, run:

wsl.exe -l -v

To upgrade your existing Linux distro to v2, run:

wsl.exe --set-version (distro name) 2

To set v2 as the default version for future installations, run:

wsl.exe --set-default-version 2
