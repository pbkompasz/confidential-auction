import { useEffect, useState } from 'react';
import './App.css';
import { useAccount, useReadContract } from 'wagmi';
import CreateAuction from './components/CreateAuction';
import { useNavigate } from 'react-router-dom';
import { Abi, Address } from 'viem';

const FACTORY_CONTRACT = '0x4b20fd1c456588cee8e8da1aebffa40892ca64b8';
const factoryAbi = {
  inputs: [],
  name: 'getAuctions',
  outputs: [
    {
      internalType: 'uint256',
      name: '',
      type: 'uint256',
    },
  ],
  stateMutability: 'view',
  type: 'function',
};

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

type Bid = {
  id: string;
  address: string;
  amount: number;
  pricePer: number;
};

function App() {
  const navigate = useNavigate();
  const [auctions, setAuctions] = useState<Auction[]>([]);
  const [myAuctions, setMyAuctions] = useState<Auction[]>([]);
  const [myBids, setMyBids] = useState<Bid[]>([]);

  const [showAuctionCreate, setShowAuctionCreate] = useState(false);

  const {
    data: auctionLength,
    isLoading,
    isFetching,
    isError,
    error,
  } = useReadContract({
    abi: factoryAbi as unknown as Abi,
    address: FACTORY_CONTRACT as Address,
    functionName: 'getAuctions',
  });

  const account = useAccount();
  console.log('Current provider:', account?.connector);

  useEffect(() => {
    setMyAuctions(
      auctions
        .map((auction) =>
          auction.organizer === account.address ? auction : undefined,
        )
        .filter((t) => !!t),
    );
  }, [auctions]);

  const onCloseWindow = (address: string) => {
    setShowAuctionCreate(false);
    if (address) {
      navigate(`/app/auction/${address}`);
    }
  };

  return (
    <div className="p-2 px-4 flex flex-col w-full">
      <div className="flex justify-between py-2">
        <h2 className="text-2xl text-left">
          Live auctions({isFetching ? 0 : auctionLength?.toString()})
        </h2>
        <button
          onClick={() => setShowAuctionCreate(true)}
          disabled={!account.isConnected}
        >
          Create new auction
        </button>
      </div>

      <table className="border-collapse border border-gray-400 bg-gray-50  text-gray-900">
        <thead>
          <tr>
            <th className="border border-gray-300">Id</th>
            <th className="border border-gray-300">Address</th>
            <th className="border border-gray-300">Name</th>
            <th className="border border-gray-300">Status</th>
          </tr>
        </thead>
        <tbody>
          {auctions.map((auction: Auction) => (
            <tr>
              <td className="border border-gray-300">{auction.id}</td>
              <td className="border border-gray-300">{auction.address}</td>
              <td className="border border-gray-300">{auction.name}</td>
              <td className="border border-gray-300">
                {auction.isLive ?? 'Live'}
                {auction.isFinished ?? 'Finished'}
                {auction.isUnstarted ?? 'Did not start'}
                {auction.isTerminate ?? 'Terminated'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <h2 className="text-2xl text-left py-2">
        My auctions({myAuctions.length})
      </h2>
      <table className="border-collapse border border-gray-400 bg-gray-50  text-gray-900">
        <thead>
          <tr>
            <th className="border border-gray-300">Id</th>
            <th className="border border-gray-300">Name</th>
            <th className="border border-gray-300">Status</th>
            <th className="border border-gray-300 w-[200px]"></th>
          </tr>
        </thead>
        <tbody>
          {auctions.map((auction: Auction) => (
            <tr>
              <td className="border border-gray-300">{auction.id}</td>
              <td className="border border-gray-300">{auction.name}</td>
              <td className="border border-gray-300">
                {auction.isLive ?? 'Live'}
                {auction.isFinished ?? 'Finished'}
                {auction.isUnstarted ?? 'Did not start'}
                {auction.isTerminate ?? 'Terminated'}
              </td>
              <td className="border border-gray-300">
                <button>Manage</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <h2 className="text-2xl text-left py-2">My positions</h2>
      <table className="border-collapse border border-gray-400 bg-gray-50  text-gray-900">
        <thead>
          <tr>
            <th className="border border-gray-300">Id</th>
            <th className="border border-gray-300">Amount</th>
            <th className="border border-gray-300">Unit Price</th>
            <th className="border border-gray-300">Total</th>
            <th className="border border-gray-300 w-[200px]"></th>
          </tr>
        </thead>
        <tbody>
          {myBids.map((bid: Bid) => (
            <tr>
              <td className="border border-gray-300">{bid.id}</td>
              <td className="border border-gray-300">{bid.amount}</td>
              <td className="border border-gray-300">{bid.pricePer}</td>
              <td className="border border-gray-300">
                {bid.amount * bid.pricePer}
              </td>
              <td className="border border-gray-300">
                <button>Cancel</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {showAuctionCreate && (
        <CreateAuction
          onClose={(newAuctionAddress: string) =>
            onCloseWindow(newAuctionAddress)
          }
        />
      )}
    </div>
  );
}

export default App;
