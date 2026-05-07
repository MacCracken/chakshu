# ADR 0001 — Binary name: `shu`

**Status**: Accepted
**Date**: 2026-05-07
**Deciders**: project owner

## Context

The project's registry name is **chakshu** (Sanskrit चक्षु — *the eye*), per the AGNOS Sovereign-stack naming convention. Registry names live in [`agnosticos/docs/development/applications/shared-crates.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/shared-crates.md) and are non-negotiable identity.

The binary name (the command users type) is a separate question. Two candidates were on the table during scaffolding:

1. **`ctop`** — would slot into the lineage `top` → `htop` → `btop` → `ctop` (the *c* mapping to *chakshu*). Strong discoverability; immediate user model.
2. **`shu`** — direct contraction of *chak**shu***. Three letters, fast to type, and accepts a fitting English backronym: **S**ystem **H**ealth **U**tility.

The `ctop` option overlaps the binary namespace with [`bcicen/ctop`](https://github.com/bcicen/ctop), a popular Go-based Docker container monitor (≈10k GitHub stars, packaged in Homebrew, Arch AUR, Debian). Different scope, different language, but the binary name is contested.

## Decision

**Ship the binary as `shu`.**

Backronym: **S**ystem **H**ealth **U**tility.

Rationale:

1. **No namespace conflict.** `shu` has no equivalent prior art as a system-monitor binary. Users installing chakshu on AGNOS get an unambiguous command; users running `bcicen/ctop` on AGNOS (via Bazaar) keep their muscle memory unbroken.
2. **Sanskrit identity preserved.** `shu` is a literal contraction of *chak**shu***. The connection to the registry name is immediate without requiring the user to know the Sanskrit etymology.
3. **English backronym fits.** *System Health Utility* is a clean three-word expansion that matches the tool's actual function. It reads naturally in onboarding docs and `--help` output without feeling forced.
4. **AGNOS command set rhythm.** AGNOS's first-party command set includes `agnoshi`, `daimon`, `cyrius`, `ark`, `nous`, `owl`, `sit`. The single-syllable `shu` fits the existing cadence; it does not need to imitate the GNU `*top*` lineage to be discoverable on AGNOS.
5. **Discoverability is solved by docs and shell completion.** The lineage-clarity argument for `ctop` mattered more in the era of tribal knowledge ("if you liked htop you'll like ctop"); on AGNOS, shell completion + `agnoshi` intent matching + explicit docs cover the discovery path without us spending the namespace.

## Consequences

- `cyrius.cyml [build].output = "shu"`.
- README, CHANGELOG, CONTRIBUTING, design-spec, roadmap, state all reference `shu` as the binary.
- The shared-crates registry entry uses `chakshu` (the project name) and notes `shu` as the binary.
- No fallback / trigger conditions tracked — the choice is clean.
- `ctop` was considered and rejected for the namespace-conflict reason recorded above. This ADR is the canonical record; future contributors should not re-litigate without new information (e.g., another tool taking over the `shu` binary name in widespread distribution).

## References

- README §Naming
- design-spec §1 (name etymology)
- [`bcicen/ctop`](https://github.com/bcicen/ctop) (alternative considered)
