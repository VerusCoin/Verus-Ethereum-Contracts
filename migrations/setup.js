const MAPPING_ETHEREUM_OWNED = 1;
const MAPPING_VERUS_OWNED = 2;
const MAPPING_PARTOF_BRIDGEVETH = 4;
const MAPPING_ISBRIDGE_CURRENCY = 8;
const MAPPING_ERC20_DEFINITION = 32;

// These are the mainnet notaries iaddresses in hex form.
const verusMainnetNotariserIDS = [];

// These are the equivelent ETH mainnet addresses of the notaries Spending R addresses
const verusMainnetNotariserSigner = [];

// These are the equivelent ETH mainnet addresses of the notaries Recovery R addresses
const verusMainnetNotariserRecovery = [];

// These are the notaries goerli iaddresses in hex form.
const verusGoerliNotariserIDS = [
    "0x429c5f2039f259c02885972852438731f21fc949",
    "0xcc86752da0c3629b7478c2b542d8b5055efee861",
    "0x9ea954a6086ba4693af454be3bfa34c9af27b6b4",
    "0xc6d8a087e1429b3676913435fb21e42569005ebc",
    "0x5653dfafa45298e7ffdbdbf8efeb3ab3b77f0a71",
    "0xb2f07c93436ff774010a6c9e8fb45206b9236455",
    "0x3c38fb272623533782e16509e7b2d9dec89d6b14",
    "0x66bc28762a7fdf88c0fa80f6c1553ff2260162db",
    "0xaf4934caf6378f429abd8381b4bdf5fbc3dcbc85",
    "0xa003129fd7e52f2770f49984e26aefdac96d10ed",
    "0xe8a86d5683f46dccb7f0815e7defeb489024bb17",
    "0x06632f9e4669f5ec782c37fc15faa6484f7a63dc",
    "0x50eba00f6dfeb95ca8ad9678ec913a944a8fe69e",
    "0xbc933f7babba837fe3291dd84f60084633daec06",
    "0xf2e2a699cebdadb6f18c9bdf735ab2828be99086",
    "0x7069a372dcd437f99abab1f4b3d0be230e2eb286",
    "0x8feb143a407bee56013156669e333b5ffe2361d8",
    "0x6fa063cf74dd44d72cb7021f2c5e51c0a34bfd9e",
    "0x39c893ffa61a12e899f8f255b5e09067922df277"];

// These are the equivelent ETH goerli addresses of the notaries Spending R addresses
const verusGoerliNotariserSigner = [
    "0x75201d47A549C39531aD22Fda6A0B2b99B5b61e1",
    "0x50af1B0fda9690C5B50fC6dc1036eC07d4C190e7",
    "0x696921eD978F93558C327d4727e49EE506Da6381",
    "0x9961E69D5B8c229e033143141A4611346C5BCEbb",
    "0xC6b9D17462b6e7c9806E17FFD4F69689A3210EFF",
    "0xAd3C15793c8276A1a9BD6c2A417a6327fd1807cD",
    "0x67583015187C9d23aa2155a89ED8850B093bD0E5",
    "0x1a7D88CeC2FdCb47f8C62024eaFe86050e7302d8",
    "0xec7BAef4303E0d6E64Ff3E9Da2226B8158104d89",
    "0xe2f1b9D1B1FCecb15Eb6b73b652c6F46B70EeC17",
    "0x21022d5e4313cc6fdDFbc55c974ff0E25F93a272",
    "0x296CEe545E270d30fC81D54B318ee8762463DF66",
    "0xA683f1D55635A1D65e003E0aF29a2A128b0c3b8A",
    "0x032a893BBdf3E93465f299142BDc736F5409475E",
    "0xC873792e8223310c24F6a226E38Ebb164A0bA1cE",
    "0x7D3FD8A015631AD5bb12FC6Fa6eDA6dAb30BE8D9",
    "0x64745BC0a92E11c7b0809F042EBAdC92b2b0d014",
    "0xC994C8eDBfa60db9E90665925686CD53cc65Bb64",
    "0x92352245278B8c973209a83B509c19Ef921925B9"];

// These are the equivelent ETH goerli addresses of the notaries Recovery R addresses
const verusGoerliNotariserRecovery = [
    "0x75201d47A549C39531aD22Fda6A0B2b99B5b61e1",
    "0x50af1B0fda9690C5B50fC6dc1036eC07d4C190e7",
    "0x696921eD978F93558C327d4727e49EE506Da6381",
    "0x9961E69D5B8c229e033143141A4611346C5BCEbb",
    "0xC6b9D17462b6e7c9806E17FFD4F69689A3210EFF",
    "0xAd3C15793c8276A1a9BD6c2A417a6327fd1807cD",
    "0x67583015187C9d23aa2155a89ED8850B093bD0E5",
    "0x1a7D88CeC2FdCb47f8C62024eaFe86050e7302d8",
    "0xec7BAef4303E0d6E64Ff3E9Da2226B8158104d89",
    "0xe2f1b9D1B1FCecb15Eb6b73b652c6F46B70EeC17",
    "0x21022d5e4313cc6fdDFbc55c974ff0E25F93a272",
    "0x296CEe545E270d30fC81D54B318ee8762463DF66",
    "0xA683f1D55635A1D65e003E0aF29a2A128b0c3b8A",
    "0x032a893BBdf3E93465f299142BDc736F5409475E",
    "0xC873792e8223310c24F6a226E38Ebb164A0bA1cE",
    "0x7D3FD8A015631AD5bb12FC6Fa6eDA6dAb30BE8D9",
    "0x64745BC0a92E11c7b0809F042EBAdC92b2b0d014",
    "0xC994C8eDBfa60db9E90665925686CD53cc65Bb64",
    "0x92352245278B8c973209a83B509c19Ef921925B9"];

// These are the development notaries iaddresses in hex form.
const TestVerusNotariserIDS = [
    "0xb26820ee0c9b1276aac834cf457026a575dfce84", 
    "0x51f9f5f053ce16cb7ca070f5c68a1cb0616ba624", 
    "0x65374d6a8b853a5f61070ad7d774ee54621f9638"];

// These are the equivelent ETH development addresses of the notaries Spending R addresses
const TestVerusNotariserSigner = [
    "0xD010dEBcBf4183188B00cafd8902e34a2C1E9f41", 
    "0xD010dEBcBf4183188B00cafd8902e34a2C1E9f41", 
    "0xD010dEBcBf4183188B00cafd8902e34a2C1E9f41"];

// These are the equivelent ETH development addresses of the notaries Recovery R addresses
const TestVerusNotariserRecovery = [
    "0xD010dEBcBf4183188B00cafd8902e34a2C1E9f41", 
    "0xD3258AD271066B7a780C68e527A6ee69ecA15b7F", 
    "0x68f56bA248E23b7d5DE4Def67592a1366431d345"];

const getNotarizerIDS = (network) => {

    if (network == "development"){
        return [TestVerusNotariserIDS, TestVerusNotariserSigner, TestVerusNotariserRecovery];
    } else if (network == "goerli"){
        return [verusGoerliNotariserIDS, verusGoerliNotariserSigner, verusGoerliNotariserRecovery];
    } else if (network == "mainnet"){
        return [verusMainnetNotariserIDS, verusMainnetNotariserSigner, verusMainnetNotariserRecovery];
    }
}

// Verus ID's in uint160 format
const id = {  
    mainnet: {
        VETH: "0x454CB83913D688795E237837d30258d11ea7c752",
        VRSC: "0x1Af5b8015C64d39Ab44C60EAd8317f9F5a9B6C4C",
        BRIDGE: "0x0200EbbD26467B866120D84A0d37c82CdE0acAEB",
        DAI: "0x8b72F1c2D326d376aDd46698E385Cf624f0CA1dA",
        DAIERC20: "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    },
    testnet: {
        VETH: "0x67460C2f56774eD27EeB8685f29f6CEC0B090B00",
        VRSC: "0xA6ef9ea235635E328124Ff3429dB9F9E91b64e2d",
        BRIDGE: "0xffEce948b8A38bBcC813411D2597f7f8485a0689",
        DAI: "0xcce5d18f305474f1e0e0ec1c507d8c85e7315fdf",
        DAIERC20: "0xB897f2448054bc5b133268A53090e110D101FFf0"
    },
    emptyuint160: "0x0000000000000000000000000000000000000000",
    emptyuint256: "0x0000000000000000000000000000000000000000000000000000000000000000"
}

const returnConstructorCurrencies = (isTestnet = false) => {

    return [
        isTestnet ? id.testnet.VETH : id.mainnet.VETH,
        isTestnet ? id.testnet.BRIDGE : id.mainnet.BRIDGE,
        isTestnet ? id.testnet.VRSC : id.mainnet.VRSC
    ]
}

// currencies that are defined are in this format:
// iaddress in hex, ERC20 contract, parent, token options, name, ticker, NFTtokenID.
const returnSetupCurrencies = (isTestnet = false) => {

    const vrsc = [
        isTestnet ? id.testnet.VRSC : id.mainnet.VRSC,
        id.emptyuint160, 
        id.emptyuint160, 
        MAPPING_VERUS_OWNED + MAPPING_PARTOF_BRIDGEVETH + MAPPING_ERC20_DEFINITION, 
        isTestnet ? "VRSCTEST" : "VRSC",
        "VRSC",
        id.emptyuint256];
        
    const bridgeeth = [
        isTestnet ? id.testnet.BRIDGE : id.mainnet.BRIDGE,
        id.emptyuint160, 
        isTestnet ? id.testnet.VRSC : id.mainnet.VRSC,
        MAPPING_VERUS_OWNED + MAPPING_ISBRIDGE_CURRENCY + MAPPING_ERC20_DEFINITION, 
        "Bridge.vETH", 
        "BETH",
        id.emptyuint256];
        
    const veth = [
        isTestnet ? id.testnet.VETH : id.mainnet.VETH,
        id.emptyuint160,
        isTestnet ? id.testnet.VRSC : id.mainnet.VRSC,
        MAPPING_ETHEREUM_OWNED + MAPPING_PARTOF_BRIDGEVETH + MAPPING_ERC20_DEFINITION, 
        isTestnet ? "ETH (Testnet)" : "ETH", 
        "ETH",
        id.emptyuint256];

    const dai = [
        isTestnet ? id.testnet.DAI : id.mainnet.DAI,
        isTestnet ? id.testnet.DAIERC20 : id.mainnet.DAIERC20,
        isTestnet ? id.testnet.VRSC : id.mainnet.VRSC, 
        MAPPING_ETHEREUM_OWNED + MAPPING_PARTOF_BRIDGEVETH + MAPPING_ERC20_DEFINITION, 
        isTestnet ? "DAI (Testnet)" : "DAI", 
        "DAI",
        id.emptyuint256];

    return [vrsc, bridgeeth, veth, dai];
}

exports.id = id;
exports.getNotarizerIDS = getNotarizerIDS;
exports.arrayofcurrencies = returnSetupCurrencies;
exports.returnConstructorCurrencies = returnConstructorCurrencies;