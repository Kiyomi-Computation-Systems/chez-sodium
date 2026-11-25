## What

<!-- One or two sentences: what changes, and why. Link the issue if there is one. -->

## Tested on

<!-- CI runs Linux x86_64 only. Say where else you ran `make test`. -->

## Checklist

- [ ] `make test` passes locally
- [ ] A behaviour change comes with a test I watched fail without it
- [ ] The title is a Conventional Commit (`feat:`, `fix:`, `docs:`, …), unless this is a milestone PR
- [ ] `README.org` and `docs/` match, if what users see changed (`make check-site`)
- [ ] `CHANGELOG.md` has an entry under `[Unreleased]`, if users can see the change
- [ ] A moved pin is with `Akku.manifest` and `Akku.lock` (`make check-pins`)
- [ ] No secret in a condition, a test name or a log
