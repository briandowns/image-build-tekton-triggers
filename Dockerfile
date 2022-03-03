ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.17.6b7
FROM ${UBI_IMAGE} as ubi
FROM ${GO_IMAGE} as builder

RUN set -x &&          \
    apk --no-cache add \
    file               \
    git                \
    make

ARG SRC="github.com/tektoncd/triggers"
ARG TAG="v0.19.0"
ARG ARCH="amd64"
RUN git clone --depth=1 https://${SRC}.git ${GOPATH}/src/${SRC}
WORKDIR ${GOPATH}/src/${SRC}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN for bin in $(ls cmd/); do                                                      \
    GOARCH=${ARCH} CGO_ENABLED=1                                                   \
    go build                                                                       \
        -gcflags=-trimpath=${GOPATH}/src                                           \
        -ldflags "-linkmode=external -extldflags \"-static -Wl,--fatal-warnings\"" \
        -o bin/${bin} ./cmd/${bin};                                                \
    done
RUN for bin in $(ls bin/); do           \
        go-assert-static.sh bin/${bin}; \
    done
RUN for bin in $(ls bin/); do           \
        go-assert-boring.sh bin/${bin}; \
    done
	    
RUN for bin in $(ls cmd/); do                 \
        install -s bin/${bin} /usr/local/bin; \
    done

FROM ubi
RUN microdnf update -y && \ 
    rm -rf /var/cache/yum
COPY --from=builder /usr/local/bin/ /usr/local/bin/
