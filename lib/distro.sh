# Detect which supported distro is running, then include specific functions

[[ -f /etc/debian_version ]] && dist=debian
[[ -f /etc/fedora-release ]] && dist=fedora
[[ -z dist ]] && { echo "I don't know what distro this is."; exit 1 }

source "$LIBRARY/distro/$dist.sh"
