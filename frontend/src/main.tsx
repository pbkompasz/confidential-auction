import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import { WagmiProvider } from 'wagmi';
import { getDefaultConfig, RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { hardhat, sepolia } from 'viem/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import '@rainbow-me/rainbowkit/styles.css';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import Layout from './Layout.tsx';
import AppLayout from './AppLayout.tsx';
import HowItWorks from './HowItWorks.tsx';
import Home from './Home.tsx';
import Auction from './Auction.tsx';

const config = getDefaultConfig({
  appName: 'Auction House',
  projectId: 'YOUR_PROJECT_ID',
  chains: [hardhat, sepolia],
  ssr: true,
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <WagmiProvider config={config}>
    <React.StrictMode>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/" element={<Layout />}>
                <Route index element={<Home />} />
                <Route path='how-it-works' element={<HowItWorks />} />
              </Route>
              <Route path="/app" element={<AppLayout />}>
                <Route index element={<App />} />
                <Route path='auction/:address' element={<Auction />} />
              </Route>
            </Routes>
          </BrowserRouter>
        </RainbowKitProvider>
      </QueryClientProvider>
    </React.StrictMode>
  </WagmiProvider>,
);
