import { FormEvent, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Address, toHex } from 'viem';
import { useAccount, useReadContract, useWriteContract } from 'wagmi';
import { createFhevmInstance, getInstance, init } from './fhevmjs';

const CONTRACT_ADDRESS = '0x309cf2aae85ad8a1db70ca88cfd4225bf17a7482';

type Auction = {
  organizer: string;
  address: string;
  id: string | number;
  name: string;
  isUnstarted: boolean;
  isLive: boolean;
  isTerminate: boolean;
  isFinished: boolean;
};

const abi = [
  {
    inputs: [],
    name: 'getAuction',
    outputs: [
      {
        components: [
          {
            internalType: 'bool',
            name: '_didAuctionFinish',
            type: 'bool',
          },
          {
            internalType: 'bool',
            name: '_didAuctionStart',
            type: 'bool',
          },
          {
            internalType: 'bool',
            name: '_didAuctionTerminate',
            type: 'bool',
          },
          {
            internalType: 'bool',
            name: '_didWinnersCalculated',
            type: 'bool',
          },
          {
            internalType: 'bool',
            name: '_isSettlePriceMet',
            type: 'bool',
          },
          {
            internalType: 'uint256',
            name: '_bidsLength',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'settlePrice',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'id',
            type: 'uint256',
          },
        ],
        internalType: 'struct AuctionStatus',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
];

function Auction() {
  const [loading, setLoading] = useState(false);
  const [instance, setInstance] = useState(getInstance());
  const [isInitialized, setIsInitialized] = useState(false);
  const readContract = useReadContract();
  const { address } = useParams();
  const [auction, setAuction] = useState<Auction>();
  const account = useAccount();
  const { writeContract } = useWriteContract();

  const [amount, setAmount] = useState<number>();
  const [pricePer, setPricePer] = useState<number>();

  // _didAuctionFinish,
  // _didAuctionStart,
  // _didAuctionTerminate,
  // _didWinnersCalculated,
  // _isSettlePriceMet,
  // _bids.length,
  // settlePrice,
  // id
  useEffect(() => {
    if (!address || !account) {
      return;
    }
    // const _auction = useReadContract({
    //   abi,
    //   address: address as Address,
    //   functionName: 'getContract',
    // });

    // setAuction({
    //   // TODO
    //   organizer: '',
    //   address,
    //   id: _auction[7],
    //   name: '',
    //   isUnstarted: !_auction[0] && !_auction[1] && _auction[2],
    //   isLive: _auction[1],
    //   isTerminate: _auction[2],
    //   isFinished: _auction[0],
    // });
  }, []);

  useEffect(() => {
    // Trick to avoid double init with HMR
    if (window.fhevmjsInitialized) {
      setLoading(true);
      createFhevmInstance().then(() => {
        const inst = getInstance();
        console.log(inst);
        setInstance(inst);
        setLoading(false);
      });

      return;
    }
    window.fhevmjsInitialized = true;

    init()
      .then(() => {
        setIsInitialized(true);
        setInstance(getInstance());
      })
      .catch((e: any | Error) => {
        console.log(e);
        setIsInitialized(false);
      });
  }, []);

  const encrypt = async () => {
    const now = Date.now();
    if (!account) {
      return null;
    }
    try {
      console.log('encrypting')
      const result = await instance
        .createEncryptedInput(CONTRACT_ADDRESS, account.address as string)
        .add256(amount as number)
        .add256(pricePer as number)
        .encrypt();

      console.log(`Took ${(Date.now() - now) / 1000}s`);
      console.log(result);
      return result;
    } catch (e) {
      console.error('Encryption error:', e);
      console.log(Date.now() - now);
    }
  };

  const bid = async (event: FormEvent) => {
    console.log('here')
    event.preventDefault();
    const result = await encrypt();

    if (!result) return;

    console.log(result.handles, result.inputProof)

    await writeContract({
      address: address as Address,
      abi,
      functionName: 'updateConfig',
      args: [
        toHex(result.handles[0]),
        toHex(result.handles[1]),
        toHex(result.inputProof),
      ],
      // TODO Read from config if should lock funds and lockAmount
      // Assume default for now and use default
      value: 1000000000000000n,
    });
  };

  return (
    <>
      <h1>{address}</h1>
      <div>
        Status: {'live'}
        <form
          onSubmit={bid}
          className="flex flex-col w-[300px] border rounded-lg p-2 items-center"
        >
          <label htmlFor="amount">Amount</label>
          <input
            name="amount"
            value={amount}
            onChange={(e) => setAmount(+e.target.value)}
            className="border"
          />
          <label htmlFor="price-per" className='mt-2'>Price per token</label>
          <input
            name="price-per"
            value={pricePer}
            onChange={(e) => setPricePer(+e.target.value)}
            className="border"
          />
          <button className="w-[50%] my-2" type="submit">
            Bid
          </button>
        </form>
      </div>
    </>
  );
}

export default Auction;
