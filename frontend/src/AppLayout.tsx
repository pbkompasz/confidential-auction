import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Link, Outlet } from 'react-router-dom';

const AppLayout = () => {
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <nav>
        <ul
          style={{
            maxWidth: '100%',
            display: 'flex',
            flexDirection: 'row',
            justifyContent: 'space-between',
            padding: '1rem 2rem',
            alignItems: 'center',
            listStyleType: 'none',
          }}
        >
          <li>
            <h1>
              <Link style={{ color: 'white' }} to="/">
                Auction House
              </Link>
            </h1>
          </li>
          <li>
            <ConnectButton />
          </li>
        </ul>
      </nav>

      <Outlet />
    </div>
  );
};

export default AppLayout;
