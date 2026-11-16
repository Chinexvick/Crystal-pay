// Every secret comes from the environment (Vercel project settings). Nothing is hard-coded.
const must = (k: string): string => {
  const v = process.env[k];
  if (!v) throw new Error(`Missing environment variable ${k}`);
  return v;
};
const opt = (k: string, d = ''): string => process.env[k] || d;

export const env = {
  get dbUrl() { return must('DATABASE_URL'); },
  get jwtSecret() { return new TextEncoder().encode(must('JWT_SECRET')); },
  get otpPepper() { return must('OTP_PEPPER'); },
  get baseUrl() { return opt('PUBLIC_BASE_URL', 'https://crystal-pay-api.vercel.app').replace(/\/$/, ''); },
  /** 'test' enables sandbox helpers (simulated CCT deposit, simulated bill delivery). Never set to test in production. */
  get mode(): 'test' | 'live' { return opt('APP_MODE', 'test') === 'live' ? 'live' : 'test'; },
  get isTest() { return this.mode === 'test'; },
  smtp: {
    get host() { return must('SMTP_HOST'); },
    get port() { return Number(opt('SMTP_PORT', '587')); },
    get user() { return must('SMTP_USER'); },
    get pass() { return must('SMTP_PASS'); },
    get fromName() { return opt('SMTP_FROM_NAME', 'Crystal Pay'); },
  },
  flw: {
    get secret() { return must('FLW_SECRET_KEY'); },
    get webhookHash() { return opt('FLW_WEBHOOK_HASH'); },
  },
  chain: {
    get name() { return opt('CHAIN', 'bsc-testnet'); },
    get rpc() { return opt('CHAIN_RPC_URL', opt('CHAIN', 'bsc-testnet') === 'bsc' ? 'https://bsc-dataseed.bnbchain.org' : 'https://data-seed-prebsc-1-s1.bnbchain.org:8545'); },
    get contract() { return opt('CCT_CONTRACT').toLowerCase(); },
    get decimals() { return Number(opt('CCT_DECIMALS', '18')); },
    get confirmations() { return Number(opt('CCT_CONFIRMATIONS', '12')); },
    get mnemonic() { return must('HD_MNEMONIC'); },
  },
};
