#docker run -p 80:80 -v openstreetmap-data:/var/lib/postgresql/12/main -d overv/openstreetmap-tile-server:1.3.10 run
FROM overv/openstreetmap-tile-server:1.3.10

COPY /var/lib/docker/volumes/openstreetmap-data /var/lib/postgresql/12/main

CMD []

