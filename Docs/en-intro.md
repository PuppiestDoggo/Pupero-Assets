# Pupero — What it is and how it works (Non‑technical overview)

Pupero is a small, self‑contained platform to simulate peer‑to‑peer trading of Monero (XMR) in a safe, test‑friendly way. It runs as a set of ready‑made services packaged with Docker, so you can start everything with a single command and explore how trading could work end‑to‑end.

Key ideas
- Easy to run locally (defaults to Monero testnet).
- Clear separation of roles: a web app for users, small APIs for features, and background workers for on‑chain actions.
- Realistic building blocks: login with 2‑factor authentication, a list of offers, simple trades, and a wallet manager that can send XMR on‑chain.

Main parts you’ll interact with
- Web app (the site): A simple interface where you can register, log in, browse offers, and simulate trades.
- Login API: Verifies users and secures sessions (passwords, tokens, optional 2FA).
- Offers API: Stores the buy/sell offers shown on the site.
- Transactions/Ledger API: Moves simulated balances when a trade is confirmed.
- Wallet Manager: Talks to the Monero wallet software and can execute on‑chain withdrawals.
- Monero node and wallet software: Real Monero components running in test mode by default.
- API Manager: A single entrypoint that forwards requests to the right service.

What a typical flow looks like
1) You register and log in on the website (can enable 2FA).
2) You browse offers and start a trade.
3) The site guides both sides through a simple confirmation (“I sent money” / “I received money”).
4) When both confirm, the system moves the simulated balance from the seller to the buyer.
5) If you choose to withdraw to a Monero address, a job is queued and later executed on‑chain by the Wallet Manager.

What it’s good for
- Demos and learning: See all moving parts of a P2P market in one place.
- Local experiments: Try changes without risking real funds thanks to the testnet default.
- A base to extend: Each piece is its own service, so you can swap implementations later.

What it’s not (yet)
- Not a full production exchange. Security hardening, compliance, audits, and production ops are your responsibility.
- Not an escrow service. The current trade confirmation is a simple, trust‑based demo flow.

How to run it
- Build the images, then start the stack with docker compose. The web app is on http://localhost:5000 and the API entrypoint is on http://localhost:8000. You can stop everything with one command too. See the technical document for exact commands.

In short: Pupero is a realistic, test‑friendly sandbox for P2P Monero trading concepts, designed to be easy to run and easy to understand.