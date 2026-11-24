# Tests and architecture

## Part A: Tests

### 1. Test observable behaviour

**Why:** a test that checks internal steps breaks on every refactor even when the behaviour is still right, and passes even when the behaviour is wrong but the steps ran.

**Rule:** drive the test through the public entry point the business uses (an insert that fires the trigger, `Database.executeBatch`, the invocable, the controller method) and assert on the outcome a user would notice: field values, records created, errors shown, results returned.

**Signals:**
- private methods made `@TestVisible` only so a test can call them directly;
- assertions on how many times an internal helper ran;
- tests that would have to change if a private method were renamed.

**In this repo:** existing classes already use `@TestVisible` helpers. Flag new ones that exist only to test internals, and suggest covering that path through the public entry point. Do not rewrite existing tests that pass just to remove them.

### 2. Keep test logic out of production code

**Signals:** `Test.isRunningTest()` branches, public static flags that force errors (`forceException = true`), or fake Ids built inside business logic.

**Fix (Proposal):** inject the boundary (the `Database` wrapper, the callout client) and pass a stub in the test, or use `Test.setMock` for callouts and `Test.createStub` / a stub provider for classes. The test then controls the failure without production code knowing about tests.

### 3. What a good test looks like

- **Named for the behaviour:** `testBatchLinksOrderWhenSapAccountIsCreatedLater`, not `test1`.
- **Arrange, act, assert:** data setup, then `Test.startTest()` / the action / `Test.stopTest()`, then assertions.
- **One behaviour per test,** with assertions that carry a message explaining the expectation.
- **Deterministic and isolated:** creates its own data in `@TestSetup` or the method, does not depend on org data or test order, and never uses `SeeAllData=true`.
- **Covers the paths that matter:** the happy path, the "nothing to do" path, a failure path, and a bulk run (200 records) for anything that runs in a trigger or batch.
- **Specific when it fails:** a failing assertion should point at the cause.

### 4. Unit versus integration tests

Salesforce tests that do real DML are integration tests: they also run every trigger, flow and validation rule on those objects. They are closest to production but slow, and a failure may come from automation you did not write.

**Balance to recommend:**
- at least one integration test per behaviour that covers the happy path with real DML;
- the variations (edge cases, error branches) as fast tests that stub the database or the callout boundary, where the class's design allows it.

If the class has no injectable boundary, do not invent one just for this. Mention it as a Proposal for when the test suite becomes slow.

### 5. Test data

- Build only the fields the behaviour needs, in small private factory methods in the test class, following the existing pattern in the file.
- Look up record types and profiles by developer name or name, never by hard-coded Id.
- When setup hits required fields or validation rules unrelated to the behaviour, that is a sign the behaviour could be tested with stubbed data instead.

## Part B: Architecture

### 6. Thin trigger handlers

**Why:** business logic inside handlers is tied to `Trigger.new` / `Trigger.oldMap` and cannot be reused from batches, Flows or the UI.

**Rule:** a trigger handler routes records. It may filter which records qualify (comparing old and new values, checking a stage transition), then passes plain records to a class that holds the business logic.

```apex
public void afterUpdate(Map<Id, Opportunity> newOpportunitiesById, Map<Id, Opportunity> oldOpportunitiesById) {
    List<Opportunity> newlyWon = new List<Opportunity>();
    for (Opportunity newOpportunity : newOpportunitiesById.values()) {
        Opportunity oldOpportunity = oldOpportunitiesById.get(newOpportunity.Id);
        if (newOpportunity.IsWon && !oldOpportunity.IsWon) {
            newlyWon.add(newOpportunity);
        }
    }
    WonOpportunityContracts.create(newlyWon);
}
```

**When the filter and the logic drift apart:** if the business class silently relies on the handler having filtered or queried something (child records, specific fields), move the filter into the business class as its own method, so the dependency is visible in one place.

### 7. Business logic from the inside out

Write the core logic so it takes plain records and parameters and does not care how it was called. The same class can then run from a trigger, a batch, a queueable, an invocable or a test. Infrastructure concerns (bypass flags, retry and re-queue, governor-limit checks, async hand-off) wrap around the core rather than living inside it.

### 8. Classes for meaningful states

**Why:** when many methods branch on the same record type or status (`if (opp.RecordTypeId == partnerTypeId)`), the branching spreads through the code base and each new rule adds another `if`.

**Proposal:** a class that represents the state and filters its own records in the constructor (`PartnerOpportunities`, `ClosedCases`), holding all logic for that state. Do this only for states the business really treats differently, not for every picklist value.

### 9. One business process, one place

Do not spread a single atomic business process across several triggers that fire each other. Keep it in one deep method or class with explicit transaction control (see `nulls-and-errors.md`). Conversely, unrelated processes that happen to fire from the same trigger should not share one method.

### 10. Logging, debug statements and dead code

- `System.debug` is for local troubleshooting only. Production diagnostics go through the org's logger (in this repo, `Logger` / `Log`), with the class name and a clear event name.
- Delete commented-out or unreachable code. Version control keeps the history.
- Unfinished work that must deploy should sit behind configuration (custom metadata or a custom permission check), not be commented out. Mention that only if the org already has such a mechanism.

### 11. Where new classes go

Follow the existing folder and naming conventions of `src/main/default`. Name new classes for the business concept they own (`OrderAccountLinking`, `WonOpportunityContracts`), not for a technical layer (`OrderHelper2`, `OrderUtilsNew`).
