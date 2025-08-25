# Dockerfile for Conduit - Speech-to-Text Transcription Tool
# Note: Audio recording in Docker requires special privileges

FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    sox \
    libsox-fmt-all \
    pulseaudio \
    alsa-utils \
    bash \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy scripts
COPY *.sh ./
COPY .env.example .env

# Make scripts executable
RUN chmod +x *.sh

# Create a non-root user
RUN useradd -m -s /bin/bash conduit && \
    chown -R conduit:conduit /app

# Switch to non-root user
USER conduit

# Set up audio group permissions
USER root
RUN usermod -a -G audio conduit
USER conduit

# Default command
CMD ["/bin/bash"]

# Usage:
# docker build -t conduit .
# docker run -it --rm \
#   --device /dev/snd \
#   -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native \
#   -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native \
#   -v ~/.config/pulse/cookie:/home/conduit/.config/pulse/cookie \
#   conduit