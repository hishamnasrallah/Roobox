# Plazo dedicated server (headless Godot export).
# Build context must contain plazo_server.x86_64 (exported by CI).
FROM ubuntu:24.04
RUN useradd --create-home plazo
WORKDIR /app
COPY plazo_server.x86_64 /app/plazo_server.x86_64
RUN chmod +x /app/plazo_server.x86_64
USER plazo
EXPOSE 7777/udp
ENTRYPOINT ["/app/plazo_server.x86_64", "--headless", "--", "--server"]
# Override to run another game, e.g.: --port 7778 --experience lava_rising
CMD ["--port", "7777", "--experience", "island"]
