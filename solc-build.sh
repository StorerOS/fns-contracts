#!/bin/sh
mkdir abi && rm ./abi/*
solc-v0.8 --bin --abi --overwrite -o ./abi @ensdomains=./ensdomains @openzeppelin=./openzeppelin ENSDeployer.sol