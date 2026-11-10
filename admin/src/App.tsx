import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { CompassIcon } from '@phosphor-icons/react'
import { useStore } from './lib/store'
import { DEMO_MODE } from './lib/config'
import { Layout } from './components/Layout'
import { ConfirmHost, ToastHost } from './components/overlays'
import { Empty } from './components/ui'
import Login from './pages/Login'
import Overview from './pages/Overview'
import Users from './pages/Users'
import UserDetail from './pages/UserDetail'
import Verifications from './pages/Verifications'
import Disputes from './pages/Disputes'
import Support from './pages/Support'
import Transactions from './pages/Transactions'
import Bills from './pages/Bills'
import Withdrawals from './pages/Withdrawals'
import Cct from './pages/Cct'
import Listings from './pages/Listings'
import Reports from './pages/Reports'
import Orders from './pages/Orders'
import Plans from './pages/Plans'
import Banners from './pages/Banners'
import Announcements from './pages/Announcements'
import Settings from './pages/Settings'
import Staff from './pages/Staff'
import Audit from './pages/Audit'

function Guard() {
  const session = useStore((s) => s.session)
  const loc = useLocation()
  if (!session || !DEMO_MODE) return <Navigate to="/login" replace state={{ from: loc.pathname + loc.search }} />
  return <Layout />
}

export default function App() {
  return (
    <>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route element={<Guard />}>
          <Route index element={<Overview />} />
          <Route path="users" element={<Users />} />
          <Route path="users/:id" element={<UserDetail />} />
          <Route path="verifications" element={<Verifications />} />
          <Route path="disputes" element={<Disputes />} />
          <Route path="support" element={<Support />} />
          <Route path="transactions" element={<Transactions />} />
          <Route path="bills" element={<Bills />} />
          <Route path="withdrawals" element={<Withdrawals />} />
          <Route path="cct" element={<Cct />} />
          <Route path="listings" element={<Listings />} />
          <Route path="reports" element={<Reports />} />
          <Route path="orders" element={<Orders />} />
          <Route path="plans" element={<Plans />} />
          <Route path="banners" element={<Banners />} />
          <Route path="announcements" element={<Announcements />} />
          <Route path="settings" element={<Settings />} />
          <Route path="staff" element={<Staff />} />
          <Route path="audit" element={<Audit />} />
          <Route path="*" element={<Empty icon={CompassIcon} title="This page does not exist">Use the menu on the left to find what you need.</Empty>} />
        </Route>
      </Routes>
      <ConfirmHost />
      <ToastHost />
    </>
  )
}
