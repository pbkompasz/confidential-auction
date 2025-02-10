module.exports = {
  istanbulReporter: ["html", "lcov"],
  providerOptions: {
    mnemonic: process.env.MNEMONIC,
  },
  providerOptions: {
    allowUnlimitedContractSize: true,
  },
  skipFiles: ["test", "fhevmTemp"],
  mocha: {
    fgrep: "[skip-on-coverage]",
    invert: true,
  },
};
