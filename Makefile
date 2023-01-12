#SHELL=/usr/bin/env bash

FNS_PKG=fns
OUT_DIR=./abi

build:
	rm -f fns-deployer && go mod tidy \
	&& GOPRIVATE="git.storeros.com" GONOPROXY="git.storeros.com" GONOSUMDB="git.storeros.com" GOINSECURE="git.storeros.com" \
	go build -ldflags "-s -w -X 'main.BuildTime=${DATE_TIME}' -X 'main.GitCommit=${COMMIT_ID}'" -o fns-deployer cmd/main.go
.PHONY:fns-deployer

contract:
	mkdir -p ${FNS_PKG} \
	&& solc-v0.8 --bin --abi --overwrite @ensdomains=./ensdomains @openzeppelin=./openzeppelin -o ${OUT_DIR} FnsDeployer.sol

# Ehtereum offical code generation
offical:contract
	/usr/bin/abigen.eth --abi ${OUT_DIR}/FnsDeployer.abi --bin ${OUT_DIR}/FnsDeployer.bin --pkg ${FNS_PKG} --out ${FNS_PKG}/FnsDeployer.go

# BCOS code generation
bcos:contract
	/usr/bin/abigen.bcos --abi ${OUT_DIR}/FnsDeployer.abi --bin ${OUT_DIR}/FnsDeployer.bin --pkg ${FNS_PKG} --out ${FNS_PKG}/FnsDeployer.go
deploy:build
	./fns-deployer deploy
