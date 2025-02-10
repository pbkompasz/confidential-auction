function Home() {
  const numberOfAuctions = 5;
  return (
    <>
      <h1>Confidential auctions built on FHE</h1>
      <p style={{ fontSize: 24 }}>
        {numberOfAuctions} live auctions. Check them out in the app!
      </p>
    </>
  );
}

export default Home;
