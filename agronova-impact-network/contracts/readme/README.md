# AgroNova Impact Network 🌱

AgroNova Impact Network is a Clarity smart contract that coordinates farmers, impact oracles, and supporters around regenerative agriculture and climate‑positive farming.

The core ideas:

- Farmers register and create impact projects.
- Oracles attest to the impact of each project.
- Supporters pledge a native “AGRO-like” token to projects.
- Simple on-chain accounting tracks balances, pledges, and project impact.

---

## Contract overview 🧩

Contract file: `contracts/agronova-impact-network.clar`

### Roles

- **Contract owner**
  - Mints the internal token.
  - Manages the list of impact oracles.

- **Farmer**
  - Registers a farmer profile.
  - Creates and closes projects.

- **Impact oracle**
  - Flagged by the contract owner.
  - Records impact scores for projects.

- **Supporter**
  - Holds internal balances.
  - Pledges tokens to active projects.

---

## Data model 🗂️

- **`balances`**  
  Internal token ledger: `principal → amount`.

- **`farmers` / `farmer-by-owner`**  
  Farmer profiles with:
  - `owner`
  - `name`
  - `region`
  - `active`

- **`projects`**  
  Projects created by farmers:
  - `owner`
  - `title`, `description`
  - `impact-score`
  - `active`
  - `start-height`, `end-height`  
    Uses `stacks-block-height` for timing.

- **`pledges`**  
  Pledges to active projects:
  - `project-id`
  - `backer`
  - `amount`
  - `claimed` (reserved for future reward logic)

- **`impact-oracles`**  
  Principals allowed to record impact:
  - `oracle`
  - `enabled`

---

## Public functions 🔑

### Admin

- `admin-mint (to principal) (amount uint)`  
  Mint internal tokens to a principal and increase total supply.

- `admin-set-oracle (oracle principal) (enabled bool)`  
  Add or remove an impact oracle.

### Token utility

- `transfer-token (to principal) (amount uint)`  
  Transfer internal balance between principals.

- `get-balance (owner principal)` (read-only)  
  View the internal token balance.

- `get-total-supply` (read-only)  
  View total minted supply.

### Farmers

- `register-farmer (name (string-ascii 50)) (region (string-ascii 50))`  
  Register the caller as a farmer and create a profile.

- `update-farmer (name (string-ascii 50)) (region (string-ascii 50)) (active bool)`  
  Update the caller’s farmer profile.

- `get-farmer-by-id (id uint)` (read-only)  
  Fetch a farmer profile by numeric ID.

- `get-farmer-by-owner-view (owner principal)` (read-only)  
  Fetch the farmer ID linked to a principal.

### Projects

- `create-project (title (string-ascii 70)) (description (string-ascii 140))`  
  Create a new project for the calling farmer.

- `close-project (project-id uint)`  
  Close an active project the farmer owns, setting `end-height`.

- `record-impact (project-id uint) (impact-score uint)`  
  Called by an oracle to set a project’s impact score.

- `get-project (project-id uint)` (read-only)  
  Fetch a project’s full data.

### Pledges

- `pledge-impact (project-id uint) (amount uint)`  
  Pledge tokens to an active project.  
  Deducts `amount` from the backer’s balance and records a pledge.

- `get-pledge (pledge-id uint)` (read-only)  
  Fetch a pledge record.

### Chain info

- `get-current-height` (read-only)  
  Returns `stacks-block-height`.

---

## Getting started with Clarinet ⚙️

From the project root:

```bash
clarinet check
```

Checks the contract syntax and type rules.

To experiment interactively:

```bash
clarinet console
```

Inside the console, you can call functions like:

```clarity
(contract-call? .agronova-impact-network get-total-supply)
```

---

## Example flows 🧪

### 1. Mint tokens to a supporter

```clarity
(contract-call? .agronova-impact-network admin-mint 'SP3SUPPORTER u1000)
```

### 2. Register a farmer

```clarity
(contract-call? .agronova-impact-network register-farmer "Farmer Alice" "Eastern Region")
```

### 3. Create a project

```clarity
(contract-call? .agronova-impact-network create-project
  "Regenerative Maize"
  "Soil health, biodiversity, and carbon capture")
```

### 4. Add an oracle and record impact

```clarity
(contract-call? .agronova-impact-network admin-set-oracle 'SP3ORACLE true)

(as-contract
  (contract-call? .agronova-impact-network record-impact u1 u10))
```

### 5. Pledge to a project

```clarity
(contract-call? .agronova-impact-network pledge-impact u1 u100)
```

---

## Line endings on Windows 🧼

If you encounter issues due to Windows line endings, normalize the Clarity contract file using PowerShell:

```powershell
(Get-Content "contracts/agronova-impact-network.clar" -Raw).Replace("`r`n", "`n") | Set-Content "contracts/agronova-impact-network.clar" -NoNewline
```

Then re-run:

```bash
clarinet check
```

---

## Deployment notes 🚀

- Deploy `agronova-impact-network` to your desired Stacks network (Devnet/Testnet/Mainnet).
- After deployment, use the fully qualified contract identifier, for example:

```clarity
(contract-call? 'ST1234...agronova-impact-network register-farmer "Farmer Alice" "Eastern Region")
```

This provides a minimal yet complete starting point to build an on-chain impact network for sustainable agriculture. 🌾
