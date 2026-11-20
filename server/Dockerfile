# Roobox dedicated server (headless Godot export).
# Build context must contain roobox_server.x86_64 (exported by CI).
FROM ubuntu:24.04
RUN useradd --create-home roobox
WORKDIR /app
COPY roobox_server.x86_64 /app/roobox_server.x86_64
RUN chmod +x /app/roobox_server.x86_64
USER roobox
EXPOSE 7777/udp
ENTRYPOINT ["/app/roobox_server.x86_64", "--headless", "--", "--server"]
# Override to run another game, e.g.: --port 7778 --experience lava_rising
CMD ["--port", "7777", "--experience", "island"]
