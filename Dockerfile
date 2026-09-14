# Runs as nonroot 65532 so the image works with a hardened pod spec
# (runAsNonRoot, readOnlyRootFilesystem). The previous version copied the
# binary into /root/ and ran as root, which crashloops under that spec with
# "permission denied" and no logs - a genuinely confusing failure.
FROM alpine:3.21

RUN addgroup -g 65532 -S nonroot && adduser -u 65532 -S nonroot -G nonroot

WORKDIR /app
COPY bin/app /app/app
RUN chmod 0555 /app/app

USER 65532:65532
EXPOSE 3000
ENTRYPOINT ["/app/app"]
