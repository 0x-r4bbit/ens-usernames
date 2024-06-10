// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { DeployTest } from "../script/DeployTest.s.sol";
import { DeploymentTestConfig } from "../script/DeploymentTestConfig.s.sol";
import { ENS } from "../contracts/ens/ENS.sol";
import { ERC20Token } from "../contracts/token/ERC20Token.sol";
import { TestToken } from "../contracts/token/TestToken.sol";
import { ENSRegistry } from "../contracts/ens/ENSRegistry.sol";
import { PublicResolver } from "../contracts/ens/PublicResolver.sol";
import { UsernameRegistrar } from "../contracts/registry/UsernameRegistrar.sol";
import { UpdatedUsernameRegistrar } from "../contracts/mocks/UpdatedUsernameRegistrar.sol";
/*import { DummyUsernameRegistrar } from "../contracts/mocks/DummyUsernameRegistrar.sol";
import { UpdatedDummyUsernameRegistrar } from "../contracts/mocks/UpdatedDummyUsernameRegistrar.sol";
import { Dummy2UsernameRegistrar } from "../contracts/mocks/Dummy2UsernameRegistrar.sol";
import { UpdatedDummy2UsernameRegistrar } from "../contracts/mocks/UpdatedDummy2UsernameRegistrar.sol";*/

contract ENSDependentTest is Test {
    bytes32 constant ETH_LABELHASH = keccak256("eth");
    bytes32 immutable ETH_NAMEHASH = getNameHash(bytes32(0x0), ETH_LABELHASH);
    DeploymentTestConfig public deploymentConfig;
    TestToken public testToken;
    ENSRegistry public ensRegistry;
    PublicResolver public publicResolver;
    DeployTest public deployment;

    address public deployer;
    address public testUser = makeAddr("testUser");

    function setUp() public virtual {
        deployment = new DeployTest();
        (testToken, ensRegistry, publicResolver, deploymentConfig) = deployment.run();

        deployer = deploymentConfig.activeNetworkConfig().deployer;

        vm.prank(deployer);
        ensRegistry.setSubnodeOwner(0x0, ETH_LABELHASH, deployer);

        assert(ensRegistry.owner(ETH_NAMEHASH) == deployer);
    }

    function getNameHash(bytes32 domain, bytes32 subdomain) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(domain, subdomain));
    }

    function registerName(
        TestToken token,
        UsernameRegistrar usernameRegistrar,
        address registrant,
        string memory username,
        address account,
        bytes32 pubkeyA,
        bytes32 pubkeyB
    )
        internal
        returns (bytes32 label, bytes32 nameHash)
    {
        label = keccak256(abi.encodePacked(username));
        nameHash = getNameHash(usernameRegistrar.ensNode(), label);
        uint256 price = usernameRegistrar.price();

        token.mint(registrant, price);
        vm.startPrank(registrant);
        token.approve(address(usernameRegistrar), price);
        usernameRegistrar.register(label, account, pubkeyA, pubkeyB);
        vm.stopPrank();
    }

    function registerName(
        TestToken token,
        UsernameRegistrar usernameRegistrar,
        address registrant,
        string memory username
    )
        internal
        returns (bytes32 label, bytes32 nameHash)
    {
        return registerName(token, usernameRegistrar, registrant, username, address(0), bytes32(0), bytes32(0));
    }

    function generateXY(bytes memory pub) internal pure returns (bytes32, bytes32) {
        require(pub.length == 65, "Invalid public key length");
        // First byte should be 0x04
        require(uint8(pub[0]) == 0x04, "Invalid public key format");

        bytes32 x;
        bytes32 y;

        // Load X and Y coordinates from the public key
        assembly {
            x := mload(add(pub, 0x21))
            y := mload(add(pub, 0x41))
        }

        return (x, y);
    }

    function keyFromXY(bytes32 x, bytes32 y) internal pure returns (bytes memory) {
        bytes memory publicKey = new bytes(65);
        publicKey[0] = bytes1(0x04);

        assembly {
            mstore(add(publicKey, 0x21), x)
            mstore(add(publicKey, 0x41), y)
        }

        return publicKey;
    }
}

contract UsernameRegistrarDeployTest is ENSDependentTest {
    UsernameRegistrar public usernameRegistrar;
    UpdatedUsernameRegistrar public updatedUsernameRegistrar;

    function setUp() public virtual override {
        super.setUp();
        (usernameRegistrar, updatedUsernameRegistrar,) = deployment.deployRegistry();
    }

    function testDeployment() public {
        assertEq(address(usernameRegistrar.token()), address(testToken), "Token address mismatch");
        assertEq(address(usernameRegistrar.ensRegistry()), address(ensRegistry), "ENS Registry address mismatch");
        assertEq(address(usernameRegistrar.resolver()), address(publicResolver), "Public resolver address mismatch");
        assertEq(
            usernameRegistrar.ensNode(), deploymentConfig.activeNetworkConfig().registry.namehash, "ENS node mismatch"
        );
        assertEq(
            usernameRegistrar.usernameMinLength(),
            deploymentConfig.activeNetworkConfig().usernameMinLength,
            "Username minimum length mismatch"
        );
        assertEq(
            usernameRegistrar.reservedUsernamesMerkleRoot(),
            deploymentConfig.activeNetworkConfig().reservedUsernamesMerkleRoot,
            "Reserved usernames merkle root mismatch"
        );
        assertEq(usernameRegistrar.parentRegistry(), address(0), "Parent registry address should be zero");
        assertEq(usernameRegistrar.controller(), deployer, "Controller address mismatch");
    }
}

contract UsernameRegistrarTestActivate is ENSDependentTest {
    UsernameRegistrar public usernameRegistrar;
    UpdatedUsernameRegistrar public updatedUsernameRegistrar;

    function setUp() public virtual override {
        super.setUp();
        (usernameRegistrar, updatedUsernameRegistrar,) = deployment.deployRegistry();
    }

    function testActivateRegistry() public {
        bytes32 label = deploymentConfig.activeNetworkConfig().registry.label;
        vm.prank(deployer);
        ensRegistry.setSubnodeOwner(ETH_NAMEHASH, label, address(usernameRegistrar));
        uint256 initialPrice = 1000;
        vm.prank(deployer);
        usernameRegistrar.activate(initialPrice);
        assertEq(usernameRegistrar.price(), initialPrice, "Registry price mismatch after activation");
        assertEq(uint8(usernameRegistrar.state()), 1, "Registry state should be active");
    }
}

contract UsernameRegistrarTestRegister is ENSDependentTest {
    UsernameRegistrar public usernameRegistrar;
    UpdatedUsernameRegistrar public updatedUsernameRegistrar;

    function setUp() public virtual override {
        super.setUp();
        (usernameRegistrar, updatedUsernameRegistrar,) = deployment.deployRegistry();
        bytes32 label = deploymentConfig.activeNetworkConfig().registry.label;
        vm.prank(deployer);
        ensRegistry.setSubnodeOwner(ETH_NAMEHASH, label, address(usernameRegistrar));

        uint256 initialPrice = 1000;
        vm.prank(deployer);
        usernameRegistrar.activate(initialPrice);
    }

    function testRegisterUsername() public {
        address registrant = testUser;
        string memory username = "testuser";
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);

        uint256 price = usernameRegistrar.price();

        assertEq(ensRegistry.owner(namehash), registrant, "Registrant should own the username hash in ENS registry");
        assertEq(
            usernameRegistrar.getAccountBalance(label), price, "Account balance should equal the registration price"
        );
        assertEq(usernameRegistrar.getAccountOwner(label), registrant, "Account owner mismatch after registration");
    }

    function testReleaseUsername() public {
        address registrant = testUser;
        string memory username = "releasetest";
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);

        vm.warp(block.timestamp + usernameRegistrar.releaseDelay() + 1);

        vm.prank(registrant);
        usernameRegistrar.release(label);

        assertEq(ensRegistry.owner(namehash), address(0), "ENS owner should be zero after release");
        assertEq(usernameRegistrar.getAccountBalance(label), 0, "Account balance should be zero after release");
        assertEq(usernameRegistrar.getAccountOwner(label), address(0), "Account owner should be zero after release");
    }

    function testUpdateRegistryPrice() public {
        uint256 newPrice = 2000;
        vm.prank(deployer);
        usernameRegistrar.updateRegistryPrice(newPrice);
        assertEq(usernameRegistrar.price(), newPrice, "Registry price should be updated");
    }

    function testMoveRegistry() public {
        vm.prank(deployer);
        usernameRegistrar.moveRegistry(updatedUsernameRegistrar);
        assertEq(
            uint8(usernameRegistrar.state()),
            uint8(UsernameRegistrar.RegistrarState.Moved),
            "Registry state should be moved"
        );
        assertEq(
            ensRegistry.owner(usernameRegistrar.ensNode()),
            address(updatedUsernameRegistrar),
            "New registry should own the ENS node"
        );
        assertEq(updatedUsernameRegistrar.price(), usernameRegistrar.price(), "Moved registry didn't retrieve price");
    }

    function testSlashSmallUsername() public {
        string memory username = "a";

        address registrant = testUser;
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);
        vm.warp(block.timestamp + usernameRegistrar.releaseDelay() / 2);

        uint256 reserveSecret = 123_456;
        address slasher = makeAddr("slasher");
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));
        vm.prank(slasher);
        usernameRegistrar.reserveSlash(secret);
        vm.roll(block.number + 1);
        vm.prank(slasher);
        usernameRegistrar.slashSmallUsername(username, reserveSecret);

        assertEq(ensRegistry.owner(namehash), address(0), "Username should be slashed and ownership set to zero");
    }

    function testSlashAddressLikeUsername() public {
        string memory username = "0xc6b95bd261233213";

        address registrant = testUser;
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);

        vm.warp(block.timestamp + usernameRegistrar.releaseDelay() / 2);

        uint256 reserveSecret = 123_456;
        address slasher = makeAddr("slasher");
        vm.startPrank(slasher);
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));

        usernameRegistrar.reserveSlash(secret);

        vm.roll(block.number + 1);
        usernameRegistrar.slashAddressLikeUsername(username, reserveSecret);

        vm.stopPrank();
        assertEq(ensRegistry.owner(namehash), address(0), "Username should be slashed and ownership set to zero");
    }

    function testRegisterUsernameWithoutAnything() public {
        address registrant = testUser;
        string memory username = "bob";
        (bytes32 label, bytes32 namehash) =
            registerName(testToken, usernameRegistrar, registrant, username, address(0), bytes32(0), bytes32(0));
        uint256 price = usernameRegistrar.price();
        assertEq(ensRegistry.owner(namehash), registrant, "Registrant should own the username hash in ENS registry");
        assertEq(
            address(ensRegistry.resolver(namehash)), address(0), "It shouldnt have a resolver"
        );
        assertEq(
            usernameRegistrar.getAccountBalance(label), price, "Account balance should equal the registration price"
        );
        assertEq(usernameRegistrar.getAccountOwner(label), registrant, "Account owner mismatch after registration");
    }

    function testRegisterUsernameWithOnlyAddress() public {
        address registrant = testUser;
        string memory username = "bob";
        (bytes32 label, bytes32 namehash) =
            registerName(testToken, usernameRegistrar, registrant, username, registrant, bytes32(0), bytes32(0));
        uint256 price = usernameRegistrar.price();
        assertEq(ensRegistry.owner(namehash), registrant, "Registrant should own the username hash in ENS registry");
        assertEq(
            PublicResolver(ensRegistry.resolver(namehash)).addr(namehash), registrant, "It should resolve an address"
        );
        (bytes32 a, bytes32 b) = PublicResolver(ensRegistry.resolver(namehash)).pubkey(namehash);
        assertEq(a, bytes32(0), "It should not resolve a pubkey a");
        assertEq(b, bytes32(0), "It should not resolve a pubkey b");
        assertEq(
            usernameRegistrar.getAccountBalance(label), price, "Account balance should equal the registration price"
        );
        assertEq(usernameRegistrar.getAccountOwner(label), registrant, "Account owner mismatch after registration");
    }

    function testRegisterUsernameWithOnlyPubkey() public {
        address registrant = testUser;
        string memory username = "bob";
        bytes memory contactCode =
            hex"04dbb31252d9bddb4e4d362c7b9c80cba74732280737af97971f42ccbdc716f3f3efb1db366880e52d09b1bfd59842e833f3004088892b7d14b9ce9e957cea9a82";

        (bytes32 x, bytes32 y) = generateXY(contactCode);

        (bytes32 label, bytes32 namehash) =
            registerName(testToken, usernameRegistrar, registrant, username, address(0), x, y);
        uint256 price = usernameRegistrar.price();
        assertEq(ensRegistry.owner(namehash), registrant, "Registrant should own the username hash in ENS registry");
        assertEq(
            PublicResolver(ensRegistry.resolver(namehash)).addr(namehash), address(0), "It should resolve an address"
        );
        (bytes32 resX, bytes32 resY) = PublicResolver(ensRegistry.resolver(namehash)).pubkey(namehash);
        assertEq(keccak256(abi.encodePacked(resX, resY)), keccak256(abi.encodePacked(x, y)), "Pubkey does not match");
        assertEq(
            usernameRegistrar.getAccountBalance(label), price, "Account balance should equal the registration price"
        );
        assertEq(usernameRegistrar.getAccountOwner(label), registrant, "Account owner mismatch after registration");
    }

    function testRegisterUsernameWithAccountAndPubKey() public {
        address registrant = testUser;
        address account = makeAddr("account");
        string memory username = "bob2";
        bytes32 label = keccak256(abi.encodePacked(username));
        uint256 registryPrice = usernameRegistrar.price();
        bytes32 usernameHash = getNameHash(usernameRegistrar.ensNode(), label);
        bytes memory contactCode =
            hex"04dbb31252d9bddb4e4d362c7b9c80cba74732280737af97971f42ccbdc716f3f3efb1db366880e52d09b1bfd59842e833f3004088892b7d14b9ce9e957cea9a82";

        (bytes32 x, bytes32 y) = generateXY(contactCode);
        testToken.mint(registrant, registryPrice);
        vm.startPrank(registrant);

        vm.expectEmit(true, true, true, true, address(testToken));
        emit ERC20Token.Approval(registrant, address(usernameRegistrar), registryPrice);
        vm.expectEmit(true, true, true, true, address(testToken));
        emit ERC20Token.Transfer(registrant, address(usernameRegistrar), registryPrice);
        vm.expectEmit(true, true, true, true, address(ensRegistry));
        emit ENS.NewOwner(usernameRegistrar.ensNode(), label, address(usernameRegistrar));
        vm.expectEmit(true, true, true, true, address(ensRegistry));
        emit ENS.NewResolver(usernameHash, address(publicResolver));
        vm.expectEmit(true, true, true, true, address(publicResolver));
        emit PublicResolver.AddrChanged(usernameHash, account);
        vm.expectEmit(true, true, true, true, address(publicResolver));
        emit PublicResolver.PubkeyChanged(usernameHash, x, y);
        vm.expectEmit(true, true, true, true, address(ensRegistry));
        emit ENS.Transfer(usernameHash, registrant);

        testToken.approveAndCall(
            address(usernameRegistrar),
            registryPrice,
            abi.encodePacked(UsernameRegistrar.register.selector, abi.encode(label, account, x, y))
        );

        vm.stopPrank();

        // Assert results
        assertEq(ensRegistry.owner(usernameHash), registrant, "ENSRegistry owner mismatch");
        assertEq(ensRegistry.resolver(usernameHash), address(publicResolver), "Resolver wrongly defined");
        assertEq(usernameRegistrar.getAccountBalance(label), registryPrice, "Wrong account balance");
        assertEq(usernameRegistrar.getAccountOwner(label), registrant, "Account owner mismatch");
        assertEq(publicResolver.addr(usernameHash), account, "Resolved address not set");

        (bytes32 resX, bytes32 resY) = publicResolver.pubkey(usernameHash);
        bytes memory resContactCode = keyFromXY(resX, resY);
        assertEq(keccak256(abi.encodePacked(resX, resY)), keccak256(abi.encodePacked(x, y)), "Pubkey does not match");
        assertEq(keccak256(resContactCode), keccak256(contactCode), "Contact code does not match");
    }

    function testSlashInvalidUsername() public {
        address registrant = testUser;
        string memory username = "alic\u00e9";
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);
        vm.warp(block.timestamp + usernameRegistrar.releaseDelay() / 2);

        uint256 reserveSecret = 1337;
        address slasher = makeAddr("slasher");
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));

        vm.prank(slasher);
        usernameRegistrar.reserveSlash(secret);
        vm.roll(block.number + 1);
        vm.prank(slasher);
        usernameRegistrar.slashInvalidUsername(username, 4, reserveSecret);

        assertEq(usernameRegistrar.getAccountBalance(label), 0, "Account balance should be zero after slashing");
        assertEq(ensRegistry.owner(namehash), address(0), "Username should be slashed and ownership set to zero");
    }

    function testShouldNotSlashValidUsername() public {
        address registrant = testUser;
        string memory username = "legituser";
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);
        vm.warp(block.timestamp + usernameRegistrar.releaseDelay() / 2);

        uint256 reserveSecret = 1337;
        address slasher = makeAddr("slasher");
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));

        vm.startPrank(slasher);
        usernameRegistrar.reserveSlash(secret);
        vm.roll(block.number + 1);

        vm.expectRevert();
        usernameRegistrar.slashInvalidUsername(username, 4, reserveSecret);
        vm.stopPrank();
    }

    function testShouldNotSlashUsernameThatStartsWith0xButIsSmallerThan12() public {
        string memory username = "0xc6b95bd26";

        address registrant = testUser;
        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);

        uint256 reserveSecret = 1337;
        address slasher = makeAddr("slasher");
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));

        vm.startPrank(slasher);
        usernameRegistrar.reserveSlash(secret);
        vm.roll(block.number + 1);

        vm.expectRevert();

        usernameRegistrar.slashAddressLikeUsername(username, reserveSecret);
        vm.stopPrank();
    }

    function testShouldNotSlashUsernameThatDoesNotStartWith0xAndIsBiggerThan12() public {
        string memory username = "0a002322c6b95bd26";

        address registrant = testUser;

        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);

        uint256 reserveSecret = 1337;
        address slasher = makeAddr("slasher");
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));

        vm.startPrank(slasher);
        usernameRegistrar.reserveSlash(secret);
        vm.roll(block.number + 1);

        vm.expectRevert();
        usernameRegistrar.slashAddressLikeUsername(username, reserveSecret);
        vm.stopPrank();
    }

    function testShouldNotSlashUsernameThatStartsWith0xButDoesNotUseHexChars() public {
        string memory username = "0xprotocolstatus";
        address registrant = testUser;

        (bytes32 label, bytes32 namehash) = registerName(testToken, usernameRegistrar, registrant, username);

        uint256 reserveSecret = 1337;
        address slasher = makeAddr("slasher");
        bytes32 secret = keccak256(abi.encodePacked(namehash, usernameRegistrar.getCreationTime(label), reserveSecret));

        vm.startPrank(slasher);
        usernameRegistrar.reserveSlash(secret);
        vm.roll(block.number + 1);

        vm.expectRevert();
        usernameRegistrar.slashAddressLikeUsername(username, reserveSecret);
        vm.stopPrank();
    }
}
