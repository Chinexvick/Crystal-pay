/**
 * Demo sign-in accepts any password. It is only switched on for local development
 * and for deployments that set VITE_DEMO_MODE=true. Any other build keeps sign-in
 * closed, so the demo can never ship by accident once real accounts exist.
 */
export const DEMO_MODE = import.meta.env.DEV || import.meta.env.VITE_DEMO_MODE === 'true'
