# Multi-Tenant ERP API

This is a demo project Rails 8.1 API for a multi-tenant ERP platform. Each client company has its own PostgreSQL database, separate from the host database that holds the list of companies.

Companies have shops, users and a master product catalog. Each shop sells products from that catalog, its own products, or both. Orders are reported to a made-up third-party API, and catalogs are updated from a CSV feed in the background.

## Requirements coverage

| Requirement | Implementation |
|---|---|
| Host application has its own database | `companies` in the primary database |
| Each company has its own database | Created at runtime, one per company ([`TenantRecord`](app/models/tenant_record.rb)) |
| Company data stays isolated | Tenant tables have no `company_id`, and queries fail unless a company is selected |
| Login API returning a token | `POST /api/v1/login` returns a JWT |
| Report each order to a third-party API | [`ReportOrderJob`](app/jobs/report_order_job.rb) and [`OrderReporter`](app/services/order_reporter.rb) |
| Authentication and data structure for reporting | Bearer API key, `Idempotency-Key` header, JSON payload |
| Ensure successful reporting | Retries, plus a sweep that re-queues anything still pending |
| Periodic product sync from CSV | [`ScheduleCatalogSyncsJob`](app/jobs/schedule_catalog_syncs_job.rb), [`SyncCatalogJob`](app/jobs/sync_catalog_job.rb), [`CatalogImport`](app/services/catalog_import.rb) |
| Sync respects tenant isolation | One job per company, running inside that company's database |
| Migrations | [`db/migrate`](db/migrate) for the host, [`db/tenant_migrate`](db/tenant_migrate) for companies |
| Seed data | [`db/seeds.rb`](db/seeds.rb) |
| Tests | [Recommended tests and what is implemented](#):|

The brief names `POST /api/login`. All routes here are versioned, so the path is `/api/v1/login`.

## Getting started

**You need:** Ruby 4.0.9 and PostgreSQL (tested with 16). Redis is not needed, and neither is `config/master.key` in development.

```bash
bin/setup --skip-server
```

This installs gems, creates and migrates the databases, and on a new database also creates the demo data, including a database for each demo company. It is safe to run again. Later, `bin/rails db:seed` re-applies the demo data without creating duplicates.

Then run the server and the background worker in two terminals:

```bash
bin/rails server
bin/jobs
```

Keep the server on port 3000, because reports go to the mock third-party API there. To use another port, set `ORDER_LEDGER_URL` for `bin/jobs` (see [Configuration](#configuration)).

Rails connects through the local PostgreSQL socket by default. To connect elsewhere, including PostgreSQL in Docker, set `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD`.

### Demo data

| | Acme Retail | Globex Stores |
|---|---|---|
| Company slug | `acme` | `globex` |
| Users | `manager@acme.example`, `cashier@acme.example` | `manager@globex.example`, `cashier@globex.example` |
| Password | `password123` | `password123` |
| Shops | Downtown (id 1), Airport (id 2) | Downtown (id 1), Airport (id 2) |
| Catalog feed | [`data/catalogs/acme.csv`](data/catalogs/acme.csv) | [`data/catalogs/globex.csv`](data/catalogs/globex.csv) |

Each company has three master products and two sample orders. Downtown sells the whole catalog at master prices. Airport sells part of it, charges its own price for one product, and has one shop-specific product.

Seeds never run in production, because these users have a known password.

## Try the API

With the server and `bin/jobs` running, log in and keep the token:

```bash
TOKEN=$(curl -s -X POST localhost:3000/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"company":"acme","email":"manager@acme.example","password":"password123"}' \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')
```

See what the Airport shop sells:

```bash
curl -s localhost:3000/api/v1/shops/2/products -H "Authorization: Bearer $TOKEN"
```

Place an order at Downtown:

```bash
curl -s -X POST localhost:3000/api/v1/shops/1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"order":{"items":[{"shop_product_id":1,"quantity":2},{"shop_product_id":2,"quantity":1}]}}'
```

The response returns straight away with `"report_status": "pending"`. Read the order again a moment later, using the `id` from the response, and the status is `reported`:

```bash
curl -s localhost:3000/api/v1/shops/1/orders/3 -H "Authorization: Bearer $TOKEN"
```

To run a catalog sync now instead of waiting for the schedule, edit a price in `data/catalogs/acme.csv`, then run:

```bash
bin/rails runner 'ScheduleCatalogSyncsJob.perform_later'
curl -s localhost:3000/api/v1/products -H "Authorization: Bearer $TOKEN"
```

## API reference

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/v1/login` | Public, 10 tries a minute per IP | Exchange credentials for a token |
| `GET` | `/api/v1/products` | Token | Master catalog |
| `GET` | `/api/v1/shops` | Token | Shops of the company |
| `GET` | `/api/v1/shops/:shop_id/products` | Token | What a shop sells, with final sku, name and price |
| `POST` | `/api/v1/shops/:shop_id/orders` | Token | Place an order |
| `GET` | `/api/v1/shops/:shop_id/orders/:id` | Token | An order, its items and its report status |

### Pagination

List endpoints accept `page` and `per_page`. The default page size is 25 and the maximum is 100.

```json
{ "data": [], "meta": { "current_page": 1, "total_pages": 2, "total_count": 3 } }
```

### Errors

Every error has the same shape, and controllers do not handle errors themselves. [`Api::V1::ApplicationController`](app/controllers/api/v1/application_controller.rb) handles them in one place.

### Multi-database approach

The app uses **Rails' built-in horizontal sharding, with shards registered at runtime** from the `companies` table. Rails normally expects shards to be listed in `config/database.yml`, which would mean a config change and a deploy for every new company. Here a new company needs only a row and a provisioning step.

| Database | Contains |
|---|---|
| Primary (host) | `companies` |
| Queue (host) | Solid Queue tables. Jobs carry IDs only, not business data |
| `tenant` template | No business data. It gives Rails a home for `db/tenant_migrate` and `db/tenant_schema.rb` |
| One per company | Shops, users, products, shop products, orders and order items |

Models show where they live through their base class. `Company` inherits from `ApplicationRecord`, and every tenant model inherits from [`TenantRecord`](app/models/tenant_record.rb). All tenant models switch together:

```ruby
TenantRecord.with_company(company) do
  Product.count   # this company's database
  Company.count   # still the host database
end
```

**Isolation is enforced, not assumed:**

- Tenant tables have no `company_id`, so a forgotten filter cannot leak another company's rows.
- A tenant query with no company selected raises an error. The default shard has no connection, so it fails instead of quietly using another database.
- Switching company inside a `with_company` block raises an error.
- The API takes the company only from the signed token, never from a parameter or header.

### Authentication

- Tokens are HS256 JWTs that last one hour and hold the user ID, company ID and expiry. The signing key is derived from `secret_key_base`, and the algorithm is fixed when decoding.
- Login needs a company slug because users live inside each company's database. A global email list in the host database would copy tenant data out of its database and need keeping in sync.
- Each request reads the company from the token, checks it is still active, selects its database and loads the user. A suspended company is locked out on its next request, even with a valid token.
- Passwords use `has_secure_password` (bcrypt), and Rails filters passwords and tokens from the logs.

### Background job design

Jobs run on **Solid Queue**, which is already part of Rails 8. It stores jobs in PostgreSQL, so the project needs no Redis, and it has recurring schedules and per-key locks built in. The queue has its own database, because it is shared infrastructure rather than company data.

| Job | Runs | Where | What it does |
|---|---|---|---|
| `ReportOrderJob` | After an order is saved, and from the sweep | Company database | Sends one report |
| `ReconcileOrderReportsJob` | Every 10 minutes | Each company in turn | Re-queues `pending` orders older than 15 minutes |
| `ScheduleCatalogSyncsJob` | Every 15 minutes | Host database | Queues one sync per active company with a feed |
| `SyncCatalogJob` | From the scheduler | Company database | Imports that company's CSV |

Schedules are in [`config/recurring.yml`](config/recurring.yml).

### Order reporting

The made-up API is `POST https://api.orderledger.example/v1/order_reports`. Each request has two important headers:

```text
Authorization: Bearer <ORDER_LEDGER_API_KEY>
Idempotency-Key: 413c7324-d14a-47dd-8337-9e92ac100d7e
```

The `Idempotency-Key` is the order's `reference`, and it stays the same on every attempt. The body is:

```json
{
  "order_reference": "413c7324-d14a-47dd-8337-9e92ac100d7e",
  "merchant": "acme",
  "shop": { "id": 1, "name": "Downtown" },
  "placed_at": "2026-11-02T03:06:40Z",
  "currency": "USD",
  "total_cents": 3900,
  "items": [
    { "sku": "TSHIRT-M", "name": "T-Shirt (M)", "quantity": 2, "unit_price_cents": 1500 },
    { "sku": "MUG-300", "name": "Coffee Mug", "quantity": 1, "unit_price_cents": 900 }
  ]
}
```

### Catalog sync

Each company's feed is a CSV file, set in `companies.catalog_csv_path`. A local file simulates the external source.

```csv
sku,name,price_cents
TSHIRT-M,T-Shirt (M),1600
MUG-300,Coffee Mug,900
```

- The file is read as a stream and written in batches of 500, using `upsert_all` on the SKU.
- Running the same file twice changes nothing, including `updated_at`.
- Bad rows are skipped and logged, and good rows in the same file still import. A row is bad if its SKU or name is blank, its price is not a whole number from 0 to 2,147,483,647, or it contains a null byte.
- If a SKU appears more than once, the last row wins.

## Project layout

```text
app/
  controllers/api/v1/   API endpoints; application_controller.rb handles auth and errors
  controllers/mock/     Development-only third-party API
  jobs/                 Reporting and catalog jobs
  jobs/concerns/        TenantJob selects the company's database
  models/               Company (host); TenantRecord and the models that inherit it (tenant)
  serializers/          JSON:API responses
  services/             AuthToken, OrderReporter, CatalogImport
config/recurring.yml    Job schedules
data/catalogs/          Simulated CSV feeds
db/migrate/             Host migrations
db/tenant_migrate/      Company migrations
lib/tasks/tenants.rake  tenants:provision and tenants:migrate
spec/                   RSpec examples; rails_helper.rb sets up company databases
```

## Tests

```bash
bundle exec rspec   # specs only
bin/ci              # style, security scans, specs and seeds
```

Specs use RSpec, and `webmock` blocks all real network calls. The suite covers the main behaviour of each area, not every edge case.
