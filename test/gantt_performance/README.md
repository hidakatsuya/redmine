# Gantt performance comparison

This optional harness compares two Redmine checkouts with the same database,
Redmined image, production configuration, Chromium version, viewport, warmups,
and measured navigation count. It is intentionally not part of the regular
test suite.

The benchmark covers the HTML Gantt path only. PDF and PNG exports are not
measured.

## Metrics

Two scenarios are measured:

- `normal`: six months, zoom 2, no selected columns
- `heavy`: twelve months, zoom 4, selected columns, relations, and progress line

Each navigation records:

- browser chart-ready, FCP, task, script, layout, and style-recalculation time
- navigation and response sizes
- DOM nodes, event listeners, and JavaScript heap
- Rails request, view, SQL, query count, and GC time from the production log
- Puma RSS and container memory
- rendered issue count and ID digest

The issue digest and logical row count must remain consistent across all runs.

## Prepare the checkouts

Create a detached worktree for the comparison base. Keep the candidate as the
current checkout. For example, to compare the parent of the current commit:

```sh
git worktree add --detach tmp/gantt_performance_baseline HEAD^
```

Redmine does not commit local configuration or `Gemfile.lock`. Copy them so
both checkouts use the same bundle and application configuration:

```sh
cp Gemfile.lock tmp/gantt_performance_baseline/Gemfile.lock
cp config/database.yml tmp/gantt_performance_baseline/config/database.yml
cp config/configuration.yml tmp/gantt_performance_baseline/config/configuration.yml
```

The comparison aborts when the two `Gemfile.lock` files are missing or differ.

Choose a result directory. Paths passed to commands running in Redmined must
use the `/redmine` mount path.

```sh
export GANTT_PERF_ROOT=tmp/gantt_performance/$(date +%Y%m%d-%H%M%S)
mkdir -p "$GANTT_PERF_ROOT"
```

Create the dedicated database from the candidate checkout. The seed refuses to
run unless the database path contains `/gantt_performance/`.

```sh
redmined -T env \
  RAILS_ENV=test \
  DATABASE_URL=sqlite3:/redmine/$GANTT_PERF_ROOT/seed.sqlite3 \
  bin/rails db:schema:load

redmined -T env \
  RAILS_ENV=test \
  DATABASE_URL=sqlite3:/redmine/$GANTT_PERF_ROOT/seed.sqlite3 \
  GANTT_PERF_MANIFEST=/redmine/$GANTT_PERF_ROOT/manifest.json \
  bin/rails runner test/gantt_performance/seed.rb
```

Precompile production assets independently for both checkouts. This avoids
comparing a precompiled candidate with an on-demand baseline.

```sh
redmined -T sh -c \
  'cd /redmine/tmp/gantt_performance_baseline && RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile'

redmined -T env \
  RAILS_ENV=production \
  SECRET_KEY_BASE_DUMMY=1 \
  bin/rails assets:precompile
```

## Run the comparison

The runner executes `before-1`, `after-1`, `after-2`, then `before-2`. Each run
starts a fresh Puma and Chromium process and copies the immutable seed database.
The reversed second pair reduces simple machine-temperature and ordering bias.

```sh
redmined -T env \
  GANTT_PERF_ROOT=/redmine/$GANTT_PERF_ROOT \
  GANTT_PERF_BEFORE_ROOT=/redmine/tmp/gantt_performance_baseline \
  GANTT_PERF_AFTER_ROOT=/redmine \
  GANTT_PERF_SEED_DATABASE=/redmine/$GANTT_PERF_ROOT/seed.sqlite3 \
  GANTT_PERF_MANIFEST=/redmine/$GANTT_PERF_ROOT/manifest.json \
  ruby test/gantt_performance/compare.rb
```

Defaults are five warmups and fifteen measured navigations per scenario and
round. A smoke run can override them:

```sh
redmined -T env \
  GANTT_PERF_ROOT=/redmine/$GANTT_PERF_ROOT \
  GANTT_PERF_BEFORE_ROOT=/redmine/tmp/gantt_performance_baseline \
  GANTT_PERF_AFTER_ROOT=/redmine \
  GANTT_PERF_SEED_DATABASE=/redmine/$GANTT_PERF_ROOT/seed.sqlite3 \
  GANTT_PERF_MANIFEST=/redmine/$GANTT_PERF_ROOT/manifest.json \
  GANTT_PERF_WARMUPS=1 \
  GANTT_PERF_ITERATIONS=2 \
  ruby test/gantt_performance/compare.rb
```

Results are written below `GANTT_PERF_ROOT`:

- `result-before-1.json`, `result-after-1.json`, etc.
- per-run SQLite copies and Puma logs
- `summary.json`
- `report.md`

Do not compare results produced with different Redmined images, bundles,
database seeds, asset modes, instrumentation, or browser versions. Keep all
runs, including the first measured run; investigate variance instead of
discarding an unfavorable sample.
