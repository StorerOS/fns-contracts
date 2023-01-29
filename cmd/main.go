package main

import (
	"encoding/hex"
	"fmt"
	"fns-controller/fns"
	"git.storeros.com/storeros/bcos-sdk/client"
	"git.storeros.com/storeros/bcos-sdk/conf"
	"git.storeros.com/storeros/bcos-sdk/core/types"
	"git.storeros.com/storeros/bcos-sdk/utils"
	"github.com/civet148/log"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"
	"math/big"
	"os"
	"os/signal"
)

const (
	Version     = "1.0.0"
	ProgramName = "fns-deployer"
)

var (
	BuildTime = "2023-01-12"
	GitCommit = ""
)

const (
	CmdNameDeploy = "deploy"
)

const (
	CmdFlagNodeUrl      = "node-url"      //BCOS node url
	CmdFlagChainID      = "chain-id"      //BCOS chain id
	CmdFlagGroupID      = "group-id"      //BCOS group id
	CmdFlagContractAddr = "contract-addr" // contract address to test
)

const (
	DefaultNodeUrl = "http://192.168.20.108:8545"
	DefaultChainID = 1
	DefaultGroupID = 1
)

var (
	ownerAddress       = "0x5B0c43004e0a68Eb197c629CE78Da62d65Aa6C03"
	ownerPrivateKey    = "3e5cd186c0de12c83fa4db6b6c5a93e64572721c4e262ce1498eaa2401658cf1"
	receiverAddress    = "0x40573435A5eECAb73e6B428ca9e028178c01d77a"
	receiverPrivateKey = "01e7a043e06abf15a192585bcd5004e59ccbdc94903160ae696a3a9d01c1b1fe"
)

type Signer struct {
}

func init() {
	log.SetLevel("info")
}

func grace() {
	//capture signal of Ctrl+C and gracefully exit
	sigChannel := make(chan os.Signal, 1)
	signal.Notify(sigChannel, os.Interrupt)
	go func() {
		for {
			select {
			case s := <-sigChannel:
				{
					if s != nil && s == os.Interrupt {
						fmt.Printf("Ctrl+C signal captured, program exiting...\n")
						close(sigChannel)
						os.Exit(0)
					}
				}
			}
		}
	}()
}

func main() {

	grace()

	local := []*cli.Command{
		deployCmd,
	}
	app := &cli.App{
		Name:     ProgramName,
		Usage:    "FNS contract deployer",
		Version:  fmt.Sprintf("v%s %s commit %s", Version, BuildTime, GitCommit),
		Flags:    []cli.Flag{},
		Commands: local,
		Action: func(cctx *cli.Context) error {

			return nil
		},
	}
	if err := app.Run(os.Args); err != nil {
		log.Errorf("exit in error %s", err)
		os.Exit(1)
		return
	}
}

func newBcosClient(cctx *cli.Context, addr string) (*client.Client, error) {

	var singer = &Signer{}
	var config = &conf.Config{
		IsHTTP:  true,
		NodeURL: cctx.String(CmdFlagNodeUrl),
		Address: addr,
		ChainID: cctx.Int64(CmdFlagChainID),
		GroupID: cctx.Int(CmdFlagGroupID),
	}
	return client.DialWithoutKey(config, singer)
}

func (s *Signer) Sign(addr common.Address, hash []byte) (signature []byte, err error) {

	var strPrivateKey string
	if addr.String() == receiverAddress {
		strPrivateKey = receiverPrivateKey
	} else if addr.String() == ownerAddress {
		strPrivateKey = ownerPrivateKey
	}
	pk, err := hex.DecodeString(strPrivateKey)
	if err != nil {
		log.Errorf("decode string [%s] error", strPrivateKey)
		return nil, err
	}
	privateKey, err := crypto.ToECDSA(pk)
	if err != nil {
		log.Errorf("private key ToECDSA error [%s]", err)
		return nil, err
	}
	signature, err = crypto.Sign(hash, privateKey)
	if err != nil {
		log.Errorf("private key Sign error [%s]", err)
		return nil, err
	}
	log.Infof("address [%s] hash [%x] signature [%x]", addr.String(), hash, signature)
	return
}

var deployCmd = &cli.Command{
	Name:      CmdNameDeploy,
	Usage:     "contract deployer",
	ArgsUsage: "",
	Flags: []cli.Flag{
		&cli.StringFlag{
			Name:  CmdFlagNodeUrl,
			Usage: "node url",
			Value: DefaultNodeUrl,
		},
		&cli.Int64Flag{
			Name:  CmdFlagChainID,
			Usage: "chain id",
			Value: DefaultChainID,
		},
		&cli.IntFlag{
			Name:  CmdFlagGroupID,
			Usage: "group id",
			Value: DefaultGroupID,
		},
	},
	Action: func(cctx *cli.Context) error {
		client, err := newBcosClient(cctx, ownerAddress)
		if err != nil {
			log.Fatal(err)
		}
		defer client.Close()
		oa, err := utils.EtherAddr(ownerAddress)
		if err != nil {
			log.Errorf(err.Error())
			return err
		}
		_ = oa
		//ra, err := utils.EtherAddr(receiverAddress)
		//if err != nil {
		//	log.Errorf(err.Error())
		//	return err
		//}
		callOpt := client.GetCallOpts()
		_ = callOpt
		transactOpt := client.GetTransactOpts()
		_ = transactOpt

		//FISCO-BCOS deploy
		addr, tx, svc, err := fns.DeployFns(transactOpt, client)
		if err != nil {
			log.Errorf("deploy error [%s]", err)
			return err
		}
		_ = svc
		log.Infof("contract address: %s", addr.Hex()) // the address should be saved
		log.Infof("contract deploy tx hash: %s", tx.Hash().Hex())

		var secret [32]byte
		var strSubDomain = "libin" //libin.fil
		secret, err = svc.Keccak(callOpt, "123456")
		strSecret := hex.EncodeToString(secret[:])
		log.Infof("secret: %s", strSecret)
		tx, receipt, err := svc.Register(transactOpt, strSubDomain, oa, big.NewInt(365*86400), secret)
		if err != nil {
			log.Errorf("register error [%s]", err)
			return err
		}
		if receipt.Status != types.Success {
			return log.Errorf("register receipt status [%v] message [%s]", receipt.Status, receipt.GetErrorMessage())
		}
		log.Infof("register 2LD domain [%s] to [%s] ok, tx hash [%s]", strSubDomain, oa.String(), tx.Hash().String())

		//var rootNode, subnode [32]byte
		//var owner common.Address
		//rootNode, err = svc.RootNode(callOpt)
		//if err != nil {
		//	log.Errorf(err.Error())
		//	return err
		//}
		//subnode, err = svc.Namehash(callOpt, rootNode, labelHash)
		//if err != nil {
		//	log.Errorf(err.Error())
		//	return err
		//}
		//owner, err = svc.Owner(callOpt, subnode)
		//if err != nil {
		//	log.Errorf("get owner error [%s]", err)
		//	return err
		//}
		//log.Infof("query sub-domain [%s] owner [%s] ok", strLabel, owner.String())
		return nil
	},
}
