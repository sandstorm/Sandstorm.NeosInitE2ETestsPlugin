# Sandstorm.NeosInitE2ETestsPlugin

A Composer plugin that scaffolds end-to-end (E2E) test infrastructure for Neos CMS packages. Run one command and get a fully wired Playwright BDD test suite with Docker-based Neos environments for both Neos 8 and Neos 9.

## What it does

When you run `composer e2e:init` inside a Neos package, the plugin copies a ready-to-use test scaffold into your project. The scaffold includes:

- A Playwright + BDD test suite (TypeScript, Gherkin feature files)
- Dockerised system-under-test (SUT) configurations for **Neos 8** and **Neos 9**
- A `Makefile` with shortcuts for setup, running tests, and managing containers
- A GitHub Actions workflow for CI

## Prerequisites

- PHP >= 8.2
- Composer >= 2.0
- Docker (for the system-under-test containers)
- Node.js >= 24 / nvm (for running Playwright tests)

## Installation

Add the plugin to your package's dev dependencies:

```bash
composer require --dev sandstorm/neos-init-e2e-tests-plugin
```

## Usage

Inside the root of your Neos package, run:

```bash
composer e2e:init
```

### Without Composer (bash bootstrap)

If you don't want to add a dev dependency just for the one-shot scaffold, run the bundled bash script instead. It downloads the template directly from GitHub and applies the same logic. From the root of your Neos package:

```bash
curl -fsSL https://raw.githubusercontent.com/sandstorm/Sandstorm.NeosInitE2ETestsPlugin/main/init-e2e-tests.sh | bash
```

To pin a specific ref, set `E2E_REF`:

```bash
E2E_REF=v1.2.3 curl -fsSL https://raw.githubusercontent.com/sandstorm/Sandstorm.NeosInitE2ETestsPlugin/main/init-e2e-tests.sh | bash
```

Requires `curl`, `tar`, `jq`, and `sed` in `PATH`.

The plugin reads your `composer.json` to determine the package name and derives the Neos package key automatically (e.g. `vendor/my-package` → `Vendor.MyPackage`). It then copies the template into your project, substituting those values wherever needed.

**The operation is non-destructive** — existing files are never overwritten. Pass `-v` to see which files are skipped:

```bash
composer e2e:init -v
```

### Overriding the package key

If the derived package key doesn't match your Neos package, set it explicitly in your `composer.json`:

```json
{
    "extra": {
        "neos": {
            "package-key": "Vendor.MyPackage"
        }
    }
}
```

### Template variables

The following placeholders are replaced in all copied files:

| Placeholder | Example value | Source |
|---|---|---|
| `{{PackageName}}` | `vendor/my-package` | `name` field in `composer.json` |
| `{{PackageKey}}` | `Vendor.MyPackage` | derived from `{{PackageName}}`, or `extra.neos.package-key` |

## Scaffolded structure

```
Tests/
├── Makefile                         # Developer shortcuts
├── README.md                        # How to run and write tests
├── E2E/                             # Playwright BDD test suite
│   ├── features/                    # Gherkin feature files
│   ├── steps/                       # TypeScript step implementations
│   ├── helpers/                     # Page objects and system utilities
│   ├── playwright.config.ts
│   └── package.json
└── system_under_test/               # Docker environments
    ├── Dockerfile
    ├── sut-base-docker-compose.yaml # Shared compose base
    ├── neos8/                       # Neos 8 + PHP 8.2 + MariaDB 10.11
    ├── neos9/                       # Neos 9 + PHP 8.5 + MariaDB 11.4
    └── sut_file_system_overrides/   # Neos/PHP/web server config

.github/
└── workflows/
    └── e2e.yml                      # GitHub Actions CI workflow
```

See `Tests/README.md` (created in your project) for instructions on running tests and writing new ones.

## How the SUT works

Each Docker environment starts a full Neos stack (FrankenPHP web server, MariaDB, Redis). On startup the container:

1. Registers your local package as a Composer path repository
2. Requires it at `@dev`
3. Runs database migrations
4. Imports the Neos demo site
5. Publishes static resources
6. Starts the web server on port `8081`

Playwright's `webServer` configuration starts the containers automatically before each test run and the global teardown stops them afterwards.

## Development

Clone the repo and install dependencies:

```bash
composer install
```

The plugin source lives in `src/` and the template that gets copied into projects lives in `template/`.
