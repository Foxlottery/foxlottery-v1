const name = "weeklyLottery";

const config = {
  localhost: {
    tokenTimedRandomSendContract: null,
    ERC20Address: "0x0165878a594ca255338adfa4d48449f69242eb8f",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    subscriptionId: 6111,
    randomSendingRules: [
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
    ],
    ticketPrice: String(10 ** 18),
    isOnlyOwner: false,
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: 100,
  },
  rinkeby: {
    tokenTimedRandomSendContract: null,
    ERC20Address: "0x4AbD33CBCE982b3DC95330963BF5E13DB51ee850",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    subscriptionId: 6111,
    randomSendingRules: [
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
    ],
    ticketPrice: String(10 ** 18),
    isOnlyOwner: false,
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: 100,
  },
  mumbai: {
    tokenTimedRandomSendContract: null,
    ERC20Address: "0x8Ff7347c2855ecC798FF1126e50458074952EAfa",
    name,
    symbol: "WLT",
    vrfCoordinator: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc",
    subscriptionId: 623,
    randomSendingRules: [
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
    ],
    ticketPrice: String(10 ** 18),
    isOnlyOwner: false,
    cycle: 86400 * 7,
    closeTimestamp:
      Math.floor(Date.now() / 1000) +
      (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
      86400 * 7,
    sellerCommissionRatio: 100,
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
  }
};

export default getConfig;
