export const AuctionFactoryAbi = [
  {
    inputs: [],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'auctionAddress',
        type: 'address',
      },
      {
        indexed: true,
        internalType: 'string',
        name: 'name',
        type: 'string',
      },
      {
        indexed: false,
        internalType: 'enum AssetType',
        name: 'assetType',
        type: 'uint8',
      },
    ],
    name: 'AuctionCreated',
    type: 'event',
  },
  {
    inputs: [
      {
        internalType: 'string',
        name: 'name',
        type: 'string',
      },
      {
        internalType: 'enum AssetType',
        name: 'assetType',
        type: 'uint8',
      },
      {
        internalType: 'uint256',
        name: 'settlePrice',
        type: 'uint256',
      },
    ],
    name: 'createAuction',
    outputs: [
      {
        internalType: 'address',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'id',
        type: 'uint256',
      },
    ],
    name: 'getAuction',
    outputs: [
      {
        internalType: 'contract ConfidentialAuction',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getPositionNFT',
    outputs: [
      {
        internalType: 'contract AuctionPosition',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getWinnerNFT',
    outputs: [
      {
        internalType: 'contract AuctionWinner',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
];
