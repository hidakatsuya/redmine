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

## Shared tool source

Use the harness from the `gantt_test` branch for every Gantt change.
See [../GANTT_TESTING.md](../GANTT_TESTING.md) for exporting it without merging
the tooling branch into the application branch. All runners resolve their
helper scripts relative to themselves, so they can live outside either checkout.
The existing `compare.rb` / `run.rb` browser benchmark remains available.

## Rails request timing and allocation profiling

`compare_requests.rb` uses the same dedicated seed, manifest and checkouts as
`compare.rb`, but measures authenticated requests with
`ActionDispatch::Integration::Session`. No browser or Puma server is started.

- `timing`: full Rack request time measured with a monotonic clock, outside any
  allocation profiler. Defaults to five warmups and fifteen measured requests,
  two rounds with reversed before/after order.
- `memory`: `memory_profiler` allocated/retained bytes and object counts for one
  warmed-up request. Defaults to three independent Rails processes per revision
  **and per scenario**. The profiler is not loaded in timing processes.
- Both modes validate the displayed issue count against the manifest and compare
  issue IDs and logical row counts across every sample, mode and revision.

`normal` and `heavy` are both measured by default. Use
`GANTT_PERF_SCENARIOS=heavy` to match the 400-issue scenario used for the original
patch's performance report. Timing and memory outputs are intentionally separate;
profiled request time and RSS are not used as performance metrics.

### Optional profiler dependency

The application's Gemfile does not need to change. Install the pinned profiler
in a dedicated directory if it is not already available:

```sh
redmined -T gem install memory_profiler --version 1.1.0 \
  --install-dir /redmine/tmp/gantt_performance/gems --no-document
```

Set `GANTT_PERF_MEMORY_PROFILER` to its absolute entrypoint. This also works when
Bundler restricts the application's dependencies. Without that variable the
runner tries `require 'memory_profiler'` and reports an actionable error if the
gem is unavailable. The result records the actual profiler version.

### Run

After the same database/checkouts/assets preparation described above:

```sh
redmined -T env \
  GANTT_PERF_ROOT=/redmine/$GANTT_PERF_ROOT \
  GANTT_PERF_BEFORE_ROOT=/redmine/tmp/gantt_performance_baseline \
  GANTT_PERF_AFTER_ROOT=/redmine \
  GANTT_PERF_SEED_DATABASE=/redmine/$GANTT_PERF_ROOT/seed.sqlite3 \
  GANTT_PERF_MANIFEST=/redmine/$GANTT_PERF_ROOT/manifest.json \
  GANTT_PERF_MEMORY_PROFILER=/redmine/tmp/gantt_performance/gems/gems/memory_profiler-1.1.0/lib/memory_profiler.rb \
  ruby test/gantt_performance/compare_requests.rb
```

Use a fresh result root for each comparison: this runner refuses to overwrite an
existing `requests/` directory. It creates a fresh SQLite copy for every process
and keeps all results and process logs, including failed runs.

For a smoke run, add:

```text
GANTT_PERF_WARMUPS=1
GANTT_PERF_ITERATIONS=1
GANTT_PERF_REQUEST_ROUNDS=1
GANTT_PERF_MEMORY_RUNS=1
```

`GANTT_PERF_REQUEST_MODES=timing` runs without the optional profiler dependency;
`GANTT_PERF_REQUEST_MODES=memory` profiles allocations only. Defaults run both.

Results under `GANTT_PERF_ROOT/requests/` include per-process JSON, logs and DB
copies; `index.json` lists the completed run set. `summary.json` contains medians
and individual round medians, while `report.md` gives the comparison table.
`analyze_requests.rb OUTPUT/requests` can regenerate both reports.

Retained bytes describe allocations made during the measured request that remain
reachable after the profiler's full GC; they are not total process memory.
Uninstrumented in-process RSS is supplementary. Use the original browser
benchmark for page-ready time and Puma RSS. These are local comparisons, not
concurrent-load tests.

## Window-resize comparison

`seed_resize.rb` and `resize.js` measure the chart controller's synchronous window-resize handler
using actual Chromium viewport changes. They also record Chromium Task/Script/Layout/RecalcStyle
execution durations over the measured interval. These are not request timings or end-to-end OS window
resize latency. No CPU throttling is applied.

Start with a copy of the visual harness's isolated seed DB in a new `tmp/gantt_performance/RUN_ID/`
directory. Run the seed through Redmined with that dedicated `DATABASE_URL` and
`GANTT_RESIZE_MANIFEST` pointing to a `resize-manifest.json` served by the local data server:

```sh
redmined -T env RAILS_ENV=test DATABASE_URL=sqlite3:/redmine/tmp/gantt_performance/RUN_ID/seed.sqlite3 GANTT_RESIZE_MANIFEST=/redmine/tmp/gantt_visual/RUN_ID/resize-manifest.json RUBYOPT=-r/redmine/tmp/gantt_tools/test/gantt_visual/frozen_clock.rb bin/rails runner /redmine/tmp/gantt_tools/test/gantt_performance/seed_resize.rb
```

The data contains independent 100- and 500-issue projects, adjacent blocking relations, and
varied progress. No synthetic DOM rows are injected. Use a fixed clock, the same bundle and
independent production assets. Copy the seed to a fresh DB for each run and set
`GANTT_VISUAL_LIMIT=1000` when using the visual harness clock.

Run in before-1, after-1, after-2, before-2 order, restarting the app on each run. Each invocation
uses a fresh browser context, validates every rendered issue ID, warms up with three viewport
changes, then changes width from 1600 to 745px and back in 45px steps. The duplicate turnaround
width produces no event, so the expected native resize count is 39 per scenario. The runner
requires at least 35 events and unchanged path coordinates, and reports actual counts.

Navigate to a control URL using the running app's origin:

```text
http://127.0.0.1:3000/?data=http://127.0.0.1:8099&output=ABSOLUTE_RESULT_DIRECTORY&run=before-1
```

Pass `resize.js` as the filename to Playwright MCP's `browser_run_code_unsafe`. The resulting
JSON records all individual handler samples, browser task durations, rendered rows/IDs/path counts,
and retained SVG nodes. Use equivalent fresh DB copies for all four runs. Report means/medians,
actual native event counts, browser/environment versions, and the timing resolution limits.

Summarize the four completed runs with:

```sh
python3 test/gantt_performance/summarize_resize.py --root tmp/gantt_performance/RUN_ID
```

The summary requires 39 events per scenario per run, identical rendered issue IDs and path counts,
and unchanged coordinates. It includes both round means, pooled mean/median/p95, browser task time
per event, retained path counts and a SHA-256 digest of rendered issue IDs.

The raw `browserCpuMs` field contains CDP execution-duration metrics in milliseconds.
It is not a measurement of whole-process CPU usage or GPU/compositor time.
