pragma solidity ^0.5.0;

/// @title Update ODIN infos to ETH
contract OracleODIN {
    // 声明一个复杂的类型，它代表一个奥丁号信息
    struct ODIN {
        string register; // 注册拥有者的比特币地址，最长36字节
        uint lastBlock;   // 新建或最后更新区块号
    }

    address private chairperson=0x9d4db8a08B362F25d45752025C40FF2De16d6C0e; //有权更新的地址

    // 声明一个变量来存储地址对应的选民数据
    mapping(uint => ODIN) private odins;


    ///登记更新一个新的奥丁号信息
    function updateODIN(
            uint shortOdin,
            string memory registerBtcAddress,
            uint btcBlockNumber
    ) external {
        require(
            msg.sender == chairperson,
            "Only chairperson can update."
        );
        odins[shortOdin]= ODIN({
            register: registerBtcAddress,
            lastBlock: btcBlockNumber
        });
    }


    // 返回指定奥丁号的注册拥有者比特币地址
    function getOdinRegisterBtcAddress(uint shortOdin ) external view
            returns ( string memory theOdinRegister)
    {
        theOdinRegister = odins[shortOdin].register;
    }
}