import { useEffect, useState } from 'react';
import { useAccount, useWriteContract } from 'wagmi';
import { Address } from 'viem';
import { AuctionFactoryAbi } from "../abi/AuctionFactory";

const FACTORY_CONTRACT  = '0xsad';

const CreateAuction = ({ onClose }: { onClose: (address: string) => void }) => {
  const [pos, setPos] = useState(0);

  const account = useAccount();

  const [auction, setAuction] = useState({
    name: '',
    symbol: '',
    assetType: '',
    paymentType: '',
    lockAmount: 0,
    shouldLockFunds: false,
    duration: 0,
    finishTime: 0,
    bidConfigResolutionStrategy: '',
    bidConfigModfiable: false,
    isConfigModifiable: false,
    maxBidsPerUser: 1,
    shouldTerminateOnSettlePrice: true,
    settlePrice: 0,
  });

  const descriptions = [
    'Select the asset you would like to you would like to auction off',
    'Select payment type',
    'Configure the auction',
  ];

  const {
    writeContract,
  } = useWriteContract();

  // createAuction(string memory name, AssetType assetType, uint256 settlePrice

  const onNext = async () => {
    if (pos == 2) {
      // const auctionAddress = await writeContract({
      //   address: FACTORY_CONTRACT as Address,
      //   abi: AuctionFactoryAbi,
      //   functionName: 'createAuction',
      //   args: [auction.name, auction.assetType, auction.settlePrice],
      // });
      // // TODO This should be called to update the config
      // // change createAuction to update config..
      // await writeContract({
      //   address: FACTORY_CONTRACT as Address,
      //   abi: AuctionFactoryAbi,
      //   functionName: 'updateConfig',
      //   args: [auction.name, auction.assetType, auction.settlePrice],
      // });
      // // @ts-ignore
      // onClose(auctionAddress);
      onClose(FACTORY_CONTRACT);
    }

    if (pos === 0) {
      if (auction.assetType && auction.name && auction.symbol) setPos(pos + 1);
    }
    if (pos === 1) {
      if (auction.paymentType) setPos(pos + 1);
    }
  };

  const onBack = () => {
    if (pos == 0) {
      return;
    }
    setPos(pos - 1);
  };

  const setAssetType = (assetType: string) => {
    setAuction({
      ...auction,
      assetType,
    });
  };

  const setName = (name: string) => {
    setAuction({
      ...auction,
      name,
    });
  };

  const setSymbol = (symbol: string) => {
    setAuction({
      ...auction,
      symbol,
    });
  };

  const setPaymentType = (paymentType: string) => {
    setAuction({
      ...auction,
      paymentType,
    });
  };

  const setBidConfigResolutionStrategy = (
    bidConfigResolutionStrategy: string,
  ) => {
    setAuction({
      ...auction,
      bidConfigResolutionStrategy,
    });
  };

  const setIsConfigModifiable = (isConfigModifiable: boolean) => {
    console.log(isConfigModifiable);
    setAuction({
      ...auction,
      isConfigModifiable,
    });
  };

  const setDuration = (duration: number) => {
    setAuction({
      ...auction,
      duration,
    });
  };

  const setFinishTime = (finishTime: number) => {
    setAuction({
      ...auction,
      finishTime,
    });
  };

  const setShouldLockFunds = (shouldTerminateOnSettlePrice: boolean) => {
    setAuction({
      ...auction,
      shouldTerminateOnSettlePrice,
    });
  };

    const setSettlePrice = (settlePrice: number) => {
    setAuction({
      ...auction,
      settlePrice,
    });
  };

  const setLockAmount = (lockAmount: number) => {
    setAuction({
      ...auction,
      lockAmount,
    });
  };

  const setBidsPerUser = (maxBidsPerUser: number) => {
    setAuction({
      ...auction,
      maxBidsPerUser,
    });
  };

  const setShouldTerminateOnSettelPrice = (
    shouldTerminateOnSettlePrice: boolean,
  ) => {
    setAuction({
      ...auction,
      shouldTerminateOnSettlePrice,
    });
  };



  return (
    <div
      className="relative z-10"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div
        className="fixed inset-0 bg-gray-500/75 transition-opacity"
        aria-hidden="true"
      ></div>

      <div className="fixed inset-0 z-10 w-screen overflow-y-auto">
        <div className="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div className="relative bg-[#1a1a1a] transform overflow-hidden rounded-lg text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
            <div className="bg-[#1a1a1a] px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
              <div className="sm:flex sm:items-start">
                <div className="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                  <h3
                    className="text-white text-base font-semibold text-8xl"
                    id="modal-title"
                  >
                    Create account
                  </h3>
                  <div className="mt-2 text-gray-500">
                    <p>{descriptions[pos]}</p>
                    {pos === 0 && (
                      <div className="flex flex-col">
                        <label htmlFor="asset-type">Asset type</label>
                        <select
                          onChange={(e) => setAssetType(e.target.value)}
                          value={auction.assetType}
                          name="assetType"
                          id="asset-type"
                        >
                          <option value="">Select an asset type</option>
                          <option value="0">ERC20</option>
                          <option value="1">ERC721</option>
                          <option value="2">ERC1155</option>
                          <option value="3">ERC4626</option>
                          <option value="4">Custom</option>
                        </select>
                        <label htmlFor="name">Name (4 to 8 characters):</label>
                        <input
                          onChange={(e) => setName(e.target.value)}
                          value={auction.name}
                          type="text"
                          id="name"
                          name="name"
                          required
                        />
                        <label htmlFor="symbol">
                          Symbol (up to 4 characters):
                        </label>
                        <input
                          onChange={(e) => setSymbol(e.target.value)}
                          value={auction.symbol}
                          type="text"
                          id="symbol"
                          name="symbol"
                          required
                        />
                      </div>
                    )}
                    {pos === 1 && (
                      <div className="flex flex-col">
                        <label htmlFor="settle-price">Settle Price</label>
                        <input
                          onChange={(e) => setSettlePrice(+e.target.value)}
                          value={auction.settlePrice}
                          type="text"
                          id="settle-price"
                          name="settle-price"
                          required
                        />
                        <label htmlFor="payment-type">Payment type</label>
                        <select
                          onChange={(e) => setPaymentType(e.target.value)}
                          value={auction.paymentType}
                          name="payment-type"
                          id="payment-type"
                        >
                          <option value="">Select payment type</option>
                          <option value="3FINAL">3% of final sell price</option>
                          <option value="10SETTLE">10% of settle price</option>
                        </select>
                        {auction.settlePrice && auction.paymentType && 
                        <>Commission price: {auction.paymentType === '3FINAL' ? 0.03 * auction.settlePrice : 0.1 * auction.settlePrice}</>
                        } 
                      </div>
                    )}
                    {pos === 2 && (
                      <div className="flex flex-col">
                        {/* TODO Blacklist accounts */}
                        <label htmlFor="config-modifiable">
                          Config modifiable on live auction
                        </label>
                        <input
                          onChange={(e) =>
                            setIsConfigModifiable(e.target.checked)
                          }
                          value={auction.isConfigModifiable.toString()}
                          type="checkbox"
                          id="config-modifiable"
                          name="config-modifiable"
                          required
                        />
                        <label htmlFor="duration">Duration</label>
                        <input
                          onChange={(e) => setDuration(+e.target.value)}
                          value={auction.duration}
                          type="text"
                          id="duration"
                          name="duration"
                          required
                        />
                        <label htmlFor="finish-time">Finish time</label>
                        <input
                          onChange={(e) => setFinishTime(+e.target.value)}
                          value={auction.finishTime}
                          type="text"
                          id="finish-time"
                          name="finish-time"
                          required
                        />
                        <label htmlFor="asset-type">
                          Bid config resolution strategy
                        </label>
                        <select
                          onChange={(e) =>
                            setBidConfigResolutionStrategy(e.target.value)
                          }
                          value={auction.bidConfigResolutionStrategy}
                          name="assetType"
                          id="asset-type"
                        >
                          <option value="">Select payment type</option>
                          <option value="3FINAL">3% of final sell price</option>
                          <option value="10SETTLE">10% of settle price</option>
                        </select>
                        <label htmlFor="should-lock-funds">
                          Users should lock funds to bid
                        </label>
                        <input
                          onChange={(e) => setShouldLockFunds(e.target.checked)}
                          value={auction.shouldLockFunds.toString()}
                          type="checkbox"
                          id="should-lock-funds"
                          name="should-lock-funds"
                          required
                        />
                        <label htmlFor="lock-amount">
                          Lock amount (in ether)
                        </label>
                        <input
                          onChange={(e) => setLockAmount(+e.target.value)}
                          value={auction.lockAmount}
                          type="text"
                          id="lock-amount"
                          name="lock-amount"
                          required
                        />
                        <label htmlFor="max-bids-per-user">
                          Max bids per user
                        </label>
                        <input
                          onChange={(e) => setBidsPerUser(+e.target.value)}
                          value={auction.maxBidsPerUser}
                          type="text"
                          id="max-bids-per-user"
                          name="max-bids-per-user"
                          required
                        />
                        <label htmlFor="should-terminate-if-price-met">
                          Should terminate auction if settle price is met
                        </label>
                        <input
                          onChange={(e) =>
                            setShouldTerminateOnSettelPrice(e.target.checked)
                          }
                          value={auction.shouldTerminateOnSettlePrice.toString()}
                          type="checkbox"
                          id="should-terminate-if-price-met"
                          name="should-terminate-if-price-met"
                          required
                        />
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-[#1a1a1a]-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
              <button
                type="button"
                className="inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-xs hover:bg-red-500 sm:ml-3 sm:w-auto"
                onClick={() => onNext()}
              >
                {pos == 2 ? 'Start' : 'Next'}
              </button>
              <button
                type="button"
                className="inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-xs hover:bg-red-500 sm:ml-3 sm:w-auto"
                onClick={() => onBack()}
              >
                {pos != 0 ? 'Back' : '-'}
              </button>
              <button
                type="button"
                className="mt-3 text-white inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 ring-1 shadow-xs ring-gray-300 ring-inset hover:bg-gray-50 sm:mt-0 sm:w-auto"
                onClick={() => onClose('')}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CreateAuction;
