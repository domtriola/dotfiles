# syntax=docker/dockerfile:1

# The pi-ailo workload: Docker's pi image, with this kit's two scripts.
# Renovate moves the tag and the digest together.
FROM docker.io/sbx/pi:1.5.2@sha256:6a8b0713fce42b90f5282bd071857fdba3c8a0fcee9bf9f11c0004c1a8bd214d
COPY --chmod=0755 files/install.sh files/startup.sh /usr/local/libexec/pi-ailo-kit/
