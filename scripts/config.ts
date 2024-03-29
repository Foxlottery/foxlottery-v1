const name = "weeklyLottery";
const randomSendingRules = [
  { raito: 1 / 0.25, sendingCount: 1 },
  { raito: 1 / 0.05, sendingCount: 4 },
  { raito: 1 / 0.01, sendingCount: 10 },
  { raito: 1 / 0.005, sendingCount: 20 },
  { raito: 1 / 0.001, sendingCount: 100 },
];
const sellerCommissionRatio = 1 / 0.05;

const config = {
  localhost: {
    lottery: null,
    ERC20Address: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    subscriptionId: 6111,
    randomSendingRules: randomSendingRules,
    ticketPrice: String(10 ** 18),
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: sellerCommissionRatio,
  },
  rinkeby: {
    lottery: null,
    ERC20Address: "0x90b5F6A0A33979f2c8f03999FF4Ba35EfF93B89A",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    subscriptionId: 6111,
    randomSendingRules: randomSendingRules,
    ticketPrice: String(10 ** 18),
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: sellerCommissionRatio,
  },
  mumbai: {
    lottery: null,
    ERC20Address: "0xdd9cF642e4dC387c7A062a6F25183d96668C50dd",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    subscriptionId: 623,
    randomSendingRules: randomSendingRules,
    ticketPrice: String(10 ** 18),
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: sellerCommissionRatio,
  },
  binanceSmartCahinTestnet: {
    lottery: null,
    ERC20Address: "0xBec8413eddaE169D36cEAF91Ba3F6ec4bB940231",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x6A2AAd07396B36Fe02a22b33cf443582f682c82f",
    keyHash:
      "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314",
    subscriptionId: 1094,
    randomSendingRules: randomSendingRules,
    ticketPrice: String(10 ** 18),
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: sellerCommissionRatio,
  },
  avalancheFuji: {
    lottery: null,
    ERC20Address: "0xBec8413eddaE169D36cEAF91Ba3F6ec4bB940231",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x6A2AAd07396B36Fe02a22b33cf443582f682c82f",
    keyHash:
      "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314",
    subscriptionId: 166,
    randomSendingRules: randomSendingRules,
    ticketPrice: String(10 ** 18),
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: sellerCommissionRatio,
  },
};

const getConfig = (networkName: string) => {
  switch (networkName) {
    case "localhost":
      return config.localhost;
    case "rinkeby":
      return config.rinkeby;
    case "mumbai":
      return config.mumbai;
    case "binanceSmartCahinTestnet":
      return config.binanceSmartCahinTestnet;
    case "avalancheFuji":
      return config.avalancheFuji;
  }
};

export default getConfig;
