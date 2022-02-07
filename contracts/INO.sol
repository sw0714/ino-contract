// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./lib/IWETH.sol";
import "./ReentrancyGuard.sol";

contract INO is ERC1155, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    address public immutable WETH;
    address payable private ReceiveToken;
    Counters.Counter private tokenCounter;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;
   
    constructor(
        address payable _receiveToken,
        address _WETH,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155(_uri) {
        ReceiveToken = _receiveToken;
        WETH = _WETH;
        name = _name;
        symbol = _symbol;
    }
    
    // Pool for INO
    struct INOPool {
        uint256 Id;
        uint256 Begin;
        uint256 End;
        uint256 Type; // 1:public, 2:private
        uint256 AmountINOTRequire; //must e18,important when init
        uint256 LockDuration; //lock after purchase
        uint256 ActivedDate;
        uint256 StopDate;
        bool IsActived;
        bool IsStopped;
        uint[] PackageIds;
    }
    
    // Package
    struct Package {
        uint256 Id;
        uint256 PoolId;
        uint256 TotalSoldCount;
        uint256 MinimumTokenSoldout;
        uint256 TotalItemCount;
        uint256 RatePerETH; // times 1e18
        address[] UsersPurchased;
    }
   
    // User
    struct User {
        uint256 Id;
        bool IsWhitelist;
        uint256 WhitelistDate;
        uint256 PurchaseTime;
        bool IsClaimed;
        uint256 TotalETHPurchase;
        uint PurchasedItemCount;
        uint[] PurchasedPackageIds;
    }

    
    mapping(uint256 => mapping(address => User)) public whitelist; // (packageId, userId) -> listuser
    mapping(uint256 => mapping(address => bool)) public purchasecheck; // (packageId, userId) -> purchasecheck
    mapping(address => mapping(uint256 => User)) private users; // (userId, poolId) -> user

    INOPool[] pools;
    Package[] packages;

    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    function packageLength() external view returns (uint256) {
        return packages.length;
    }
    
    // Add Whitelist function 
    function addWhitelist(address user, uint256 pid) public onlyOwner {
        uint256 poolIndex = pid.sub(1);
        uint[] memory packageIds = pools[poolIndex].PackageIds;
        uint256 packagesLength = packageIds.length;
        for (uint256 i = 0; i < packagesLength; i++)
        {
            uint256 packageId = packageIds[i];
            whitelist[packageId][user].Id = pid;
            whitelist[packageId][user].IsWhitelist = true;
            whitelist[packageId][user].WhitelistDate = block.timestamp;
        }
    }
    
    // Add Multiple Whitelist function 
    function addMulWhitelist(address[] memory user, uint256 pid)
        public onlyOwner        
    {
        uint256 poolIndex = pid.sub(1);
        uint[] memory packageIds = pools[poolIndex].PackageIds;
        uint256 packagesLength = packageIds.length;
        for (uint256 i = 0; i < user.length; i++) {
            for (uint256 j = 0; j < packagesLength; j++) {
                uint256 packageId = packageIds[j];
                whitelist[packageId][user[i]].Id = pid;
                whitelist[packageId][user[i]].IsWhitelist = true;
                whitelist[packageId][user[i]].WhitelistDate = block.timestamp;
            }
        }
    }
     // Update existing user whitelist condition
    function updateWhitelist(
        address user,
        uint256 pid,
        bool isWhitelist
    ) public onlyOwner {
        uint256 poolIndex = pid.sub(1);
        uint[] memory packageIds = pools[poolIndex].PackageIds;
        uint256 packagesLength = packageIds.length;
        for (uint256 i = 0; i < packagesLength; i++)
        {
            uint256 packageId = packageIds[i];
            whitelist[packageId][user].IsWhitelist = isWhitelist;
        }
    }

   // Check if user IsWhitelist
    function IsWhitelist(address user, uint256 pid) public view returns (bool) {
        uint256 poolIndex = pid.sub(1);
        uint[] memory packageIds = pools[poolIndex].PackageIds;
        return whitelist[packageIds[0]][user].IsWhitelist;
    }
    
    
    //Add package to pool
    function addPackageToPool(
        uint256 _PoolId,
        uint256 _MinimumTokenSoldout,
        uint256 _TotalItemCount,
        uint256 _RatePerETH
    ) public onlyOwner {
        uint256 id = packages.length.add(1);
        packages.push(
            Package({
                Id : id,
                PoolId : _PoolId,
                TotalSoldCount : 0,
                MinimumTokenSoldout : _MinimumTokenSoldout,
                TotalItemCount : _TotalItemCount,
                RatePerETH : _RatePerETH,
                UsersPurchased : new address[](0)
            })
        );
        uint256 poolIndex = _PoolId.sub(1);    
        pools[poolIndex].PackageIds.push(id);
    }

    //Add Pool
    function addPool(
        uint256 _Begin,
        uint256 _End,
        uint256 _Type, //1:public, 2:private
        uint256 _AmountINOTRequire, //must e18,important when init
        uint256 _LockDuration //lock after purchase
    ) public onlyOwner {
        pools.push(
            INOPool({
                Id : pools.length.add(1),
                Begin : _Begin,
                End : _End,
                Type : _Type, //1:public, 2:private
                AmountINOTRequire : _AmountINOTRequire, //must e18,important when init
                LockDuration : _LockDuration, //lock after purchase
                ActivedDate : 0,
                StopDate : 0,
                IsActived : false,
                IsStopped : true,
                PackageIds: new uint[](0)
            })
        );
    }

    // Update the pool
    function updatePool(
        uint256 pid,
        uint256 _Begin,
        uint256 _End,
        uint256 _Type,
        uint256 _AmountINOTRequire,
        uint256 _LockDuration
    ) public onlyOwner {
        uint256 poolIndex = pid.sub(1);
        if (_Begin > 0) {
            pools[poolIndex].Begin = _Begin;
        }
        if (_End > 0) {
            pools[poolIndex].End = _End;
        }
        if (_Type > 0) {
            pools[poolIndex].Type = _Type;
        }
        if (_AmountINOTRequire > 0) {
            pools[poolIndex].AmountINOTRequire = _AmountINOTRequire;
        }
        if (_LockDuration > 0) {
            pools[poolIndex].LockDuration = _LockDuration;
        }
    }

    // Stopping the pool
    function stopPool(uint256 pid) public onlyOwner {
        uint256 poolIndex = pid.sub(1);
        pools[poolIndex].IsActived = false;
        pools[poolIndex].IsStopped = true;

        pools[poolIndex].StopDate = block.timestamp;
    }
    
    // Activating the pool
    function activePool(uint256 pid) public onlyOwner {
        uint256 poolIndex = pid.sub(1);
        pools[poolIndex].IsActived = true;
        pools[poolIndex].IsStopped = false;
        pools[poolIndex].ActivedDate = block.timestamp;
        pools[poolIndex].StopDate = 0;
    }

    //Update package
    function updatePackage(
        uint256 _PackageId,
        uint256 _MinimumTokenSoldout,
        uint256 _TotalItemCount,
        uint256 _RatePerETH
    ) public onlyOwner {
        uint256 packageIndex = _PackageId.sub(1);
        if (_MinimumTokenSoldout > 0) {
            packages[packageIndex].MinimumTokenSoldout = _MinimumTokenSoldout;
        }
        if (_TotalItemCount > 0) {
            packages[packageIndex].TotalItemCount = _TotalItemCount;
        }
        if (_RatePerETH > 0) {
            packages[packageIndex].RatePerETH = _RatePerETH;
        }
    }
    
    function getBalanceItemByPackageId(uint256 packageId)
        public
        view
        returns (uint256)
    {
        uint256 packageIndex = packageId.sub(1);
        return packages[packageIndex].TotalItemCount;
    }
    
    function getRemainINOToken(uint256 packageId) public view returns (uint256) {
        uint256 packageIndex = packageId.sub(1);
        return packages[packageIndex].TotalItemCount.sub(packages[packageIndex].TotalSoldCount);
    }

    // To Do: Purchase function 
    function purchaseINO(uint256 packageId, uint256 quantity)
        public
        payable
        nonReentrant
    {
        uint256 packageIndex = packageId.sub(1);
        uint256 poolId = packages[packageIndex].PoolId;
        uint256 poolIndex = poolId.sub(1);
        
        require(pools[poolIndex].IsActived, "invalid pool");
        require(
            block.timestamp >= pools[poolIndex].Begin &&
                block.timestamp <= pools[poolIndex].End,
            "invalid time"
        );
        // check user
        if (pools[poolIndex].Type == 2) //private
            require(IsWhitelist(msg.sender, poolId), "invalid user");

        // check eth
        uint256 ethAmount = msg.value;
        uint256 calcItemAmount = ethAmount.mul(packages[packageIndex].RatePerETH).div(1e36);
        require(calcItemAmount >= quantity, "insufficient funds");
        // check remained token
        uint256 remainToken = getRemainINOToken(packageId);
        require(
            remainToken > packages[packageIndex].MinimumTokenSoldout,
            "INO sold out"
        );
        require(remainToken >= quantity, "INO sold out");

        whitelist[packageId][msg.sender].TotalETHPurchase = whitelist[packageId][msg.sender]
            .TotalETHPurchase
            .add(ethAmount);

        whitelist[packageId][msg.sender].PurchasedItemCount = whitelist[packageId][msg.sender]
            .PurchasedItemCount
            .add(quantity);
        whitelist[packageId][msg.sender].PurchaseTime = block.timestamp;

        if(!purchasecheck[packageId][msg.sender]){
            packages[packageIndex].UsersPurchased.push(msg.sender);
            purchasecheck[packageId][msg.sender] = true;
            users[msg.sender][poolId].PurchasedPackageIds.push(packageId);
        }
        packages[packageIndex].TotalSoldCount = packages[packageIndex].TotalSoldCount.add(
            quantity
        );
        IWETH(WETH).deposit{value: ethAmount}();
    }

    // To Do: Claim Pool
    function claimPool(uint256 pid) public nonReentrant {
        uint256 poolIndex = pid.sub(1);
        //check user
        if (pools[poolIndex].Type == 2) //private
            require(IsWhitelist(msg.sender, pid), "invalid user");
        require(block.timestamp > pools[poolIndex].End.add(pools[poolIndex].LockDuration), "not on time for claiming NFTs");
        uint[] memory packageIds = users[msg.sender][pid].PurchasedPackageIds;
        uint256 packagesLength = packageIds.length;
        require(!whitelist[packageIds[0]][msg.sender].IsClaimed, "user already claimed");
        for (uint256 i = 0; i < packagesLength; i++)
        {
            uint256 packageId = packageIds[i];
            if(purchasecheck[packageId][msg.sender]){
                uint256 itemCount = whitelist[packageId][msg.sender].PurchasedItemCount;
                _mint(msg.sender, packageId, itemCount, '');
                whitelist[packageId][msg.sender].IsClaimed = true;
            }
        }
    }
    
    function getPoolInfo(uint256 pid) public view
        returns ( INOPool memory retSt )
    {
        uint256 poolIndex = pid.sub(1);
        return pools[poolIndex];
    }

    function getPackageInfo(uint256 packageId) public view
        returns ( Package memory retSt )
    {
        uint256 packageIndex = packageId.sub(1);
        return packages[packageIndex];
    }

    function getPurchasedPackageIds(address user_, uint256 pid) public view
        returns ( uint[] memory )
    {
        return users[user_][pid].PurchasedPackageIds;
    }

    //withdraw ETH after INO
    function withdrawPoolFund() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "not enough fund");
        ReceiveToken.transfer(balance);
    }
}
