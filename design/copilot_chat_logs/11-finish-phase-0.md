johncip: what remains necessary for closing out phase 0?

GitHub Copilot: Looking at the implementation plan, Phase 0 has one remaining item:

```markdown
- [ ] Decide matching strategy for parameterized vs literal SQL refactoring
```

This is referenced in `api_support.md` under "Matching Strategy Decision (TBD)":

> If user refactors `db.run("...?", val)` to `db.run("...'val'")`:
> - [ ] Fail (strict: query structure changed)
> - [ ] Warn (structure changed but semantically equivalent)
> - [ ] Match (normalize both for comparison)

And in `investigations.md` as an open question:

> **Q: What happens if user refactors parameterized → literal SQL (or vice versa)?**
> A: TBD. Options:
> - Fail (strict: query structure changed)
> - Warn (structure changed but semantically equivalent)
> - Match (normalize both for comparison)

**Recommendation**: Start with **Fail (strict)**. Rationale:
1. Matches VCR's philosophy—cassettes are explicit snapshots of behavior
2. Simpler to implement (no normalization logic)
3. Forces re-recording when query structure changes, which is safer
4. Can relax later if it proves too annoying in practice

If you agree, I can update the documents to mark this decided and close out Phase 0.

johncip: ideally it would fail but we'd have been detailed enough in what we stored that we could give a descriptive failure message.

it shouldn't be a blocker or anything, but that's worth having if it doesn't cost too much.

GitHub Copilot: Makes sense—fail strictly, but with a helpful diff that shows exactly what changed (template vs literal, parameter count, etc.). The cassette format already captures `sql` and `params` separately, so we have the info needed. 

Using "Multi-Replace String in Files"


```

```

```

```

```

```
Phase 0 is now complete. All investigation items are checked off:

- Data types confirmed (all strings, CSV sufficient)
- Prepared statements investigated (capture at intercept time)
- Two-phase model confirmed
- API methods documented
- Cassette format designed
- Matching strategy decided: strict fail with descriptive diff

Ready for Phase 1 (MVP implementation).

Made changes.