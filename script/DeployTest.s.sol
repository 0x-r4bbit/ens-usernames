// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { DeploymentTestConfig } from "./DeploymentTestConfig.s.sol";
import { TestToken } from "../contracts/token/TestToken.sol";
import { ENSRegistry } from "../contracts/ens/ENSRegistry.sol";
import { PublicResolver } from "../contracts/ens/PublicResolver.sol";
import { UsernameRegistrar } from "../contracts/registry/UsernameRegistrar.sol";
import { UpdatedUsernameRegistrar } from "../contracts/mocks/UpdatedUsernameRegistrar.sol";
import { DummyUsernameRegistrar } from "../contracts/mocks/DummyUsernameRegistrar.sol";
import { UpdatedDummyUsernameRegistrar } from "../contracts/mocks/UpdatedDummyUsernameRegistrar.sol";
import { Dummy2UsernameRegistrar } from "../contracts/mocks/Dummy2UsernameRegistrar.sol";
import { UpdatedDummy2UsernameRegistrar } from "../contracts/mocks/UpdatedDummy2UsernameRegistrar.sol";

contract DeployTest is BaseScript {
    DeploymentTestConfig deploymentTestConfig;
    TestToken token;
    ENSRegistry ensRegistry;
    PublicResolver publicResolver;

    constructor() {
        deploymentTestConfig = new DeploymentTestConfig(broadcaster);
    }

    function run() public returns (TestToken, ENSRegistry, PublicResolver, DeploymentTestConfig) {
        DeploymentTestConfig.NetworkConfig memory config = deploymentTestConfig.activeNetworkConfig();

        vm.startBroadcast(broadcaster);
        token = new TestToken();
        ensRegistry = new ENSRegistry();
        publicResolver = new PublicResolver(ensRegistry);
        vm.stopBroadcast();

        return (token, ensRegistry, publicResolver, deploymentTestConfig);
    }

    function deployRegistry() public returns (UsernameRegistrar, UpdatedUsernameRegistrar, DeploymentTestConfig) {
        DeploymentTestConfig.NetworkConfig memory config = deploymentTestConfig.activeNetworkConfig();

        vm.startBroadcast(broadcaster);
        UsernameRegistrar usernameRegistrar = new UsernameRegistrar(
            token,
            ensRegistry,
            publicResolver,
            config.registry.namehash,
            config.usernameMinLength,
            config.reservedUsernamesMerkleRoot,
            address(0)
        );

        UpdatedUsernameRegistrar updatedUsernameRegistrar = new UpdatedUsernameRegistrar(
            token,
            ensRegistry,
            publicResolver,
            config.registry.namehash,
            config.usernameMinLength,
            config.reservedUsernamesMerkleRoot,
            address(usernameRegistrar)
        );
        vm.stopBroadcast();

        return (usernameRegistrar, updatedUsernameRegistrar, deploymentTestConfig);
    }

    function deployDummy()
        public
        returns (DummyUsernameRegistrar, UpdatedDummyUsernameRegistrar, DeploymentTestConfig)
    {
        DeploymentTestConfig.NetworkConfig memory config = deploymentTestConfig.activeNetworkConfig();

        vm.startBroadcast(broadcaster);

        DummyUsernameRegistrar dummyUsernameRegistrar = new DummyUsernameRegistrar(
            token,
            ensRegistry,
            publicResolver,
            config.dummyRegistry.namehash,
            config.usernameMinLength,
            config.reservedUsernamesMerkleRoot,
            address(0)
        );

        UpdatedDummyUsernameRegistrar updatedDummyUsernameRegistrar = new UpdatedDummyUsernameRegistrar(
            token,
            ensRegistry,
            publicResolver,
            config.dummyRegistry.namehash,
            config.usernameMinLength,
            config.reservedUsernamesMerkleRoot,
            address(dummyUsernameRegistrar)
        );
        vm.stopBroadcast();

        return (dummyUsernameRegistrar, updatedDummyUsernameRegistrar, deploymentTestConfig);
    }

    function deployDummy2() public returns (Dummy2UsernameRegistrar, UpdatedDummy2UsernameRegistrar) {
        DeploymentTestConfig.NetworkConfig memory config = deploymentTestConfig.activeNetworkConfig();

        vm.startBroadcast(broadcaster);

        Dummy2UsernameRegistrar dummy2UsernameRegistrar = new Dummy2UsernameRegistrar(
            token,
            ensRegistry,
            publicResolver,
            config.dummy2Registry.namehash,
            config.usernameMinLength,
            config.reservedUsernamesMerkleRoot,
            address(0)
        );

        UpdatedDummy2UsernameRegistrar updatedDummy2UsernameRegistrar = new UpdatedDummy2UsernameRegistrar(
            token,
            ensRegistry,
            publicResolver,
            config.dummy2Registry.namehash,
            config.usernameMinLength,
            config.reservedUsernamesMerkleRoot,
            address(dummy2UsernameRegistrar)
        );

        vm.stopBroadcast();

        return (dummy2UsernameRegistrar, updatedDummy2UsernameRegistrar);
    }
}
