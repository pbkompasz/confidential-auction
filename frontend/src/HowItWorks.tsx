import './HowItWorks.css';

function App() {
  return (
    <>
      <h2>How it works</h2>
      <div className="container">
        <div className="item">
          <p className="title">1. Select an assets</p>
          <p>Alternatively you can launch a new asset from right here</p>
          <p>Supported assets:</p>
          <ul>
            <li>ERC20</li>
            <li>ERC721</li>
            <li>ERC1155</li>
            <li>ERC4626 </li>
            <li>Custom offerings: Ad Auction</li>
          </ul>
        </div>
        <div className="item">
          <p className="title">2. Select the payment type:</p>
          <ul>
            <li>3% of final sell price</li>
            <li>10% of settle price</li>
          </ul>
        </div>
        <div className="item">
          <p className="title">3. Configure your auction</p>
          <p>
            Don't worry you will be able to modify the parameters as the auction
            or cancel it entirely with no hidden costs
          </p>
        </div>
        <div className="item">
          <p className="title">4. Start the auction</p>
        </div>
        <div className="item">
          <p className="title">5. The auction is live</p>
          <p>
            Users can submit bids until the deadline or the threshold is met
          </p>
        </div>
        <div className="item">
          <p className="title">6. Auction concluded</p>
          <p>Distribute the assets and CLAIM your coins</p>
        </div>
      </div>
    </>
  );
}

export default App;
