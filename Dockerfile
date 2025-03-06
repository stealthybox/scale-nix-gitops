FROM scrapbook-dev AS build
ENV CGO_ENABLED=1
WORKDIR /app
COPY ./scrapbook-dev /app
RUN go mod download
RUN mkdir /tmp
RUN /nix/store/*-environment-develop/activate \
  --env /nix/store/*-environment-develop \
  --shell bash -c "go build"

FROM scrapbook-runtime AS runtime
WORKDIR /www
COPY --from=build /app/views /www/views
COPY --from=build /app/public /www/public
COPY --from=build /app/go-image-app /bin/
