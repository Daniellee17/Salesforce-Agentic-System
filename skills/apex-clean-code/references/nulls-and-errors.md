# Nulls, validation, exceptions and transactions

## 1. Null versus empty

- **Null** means there is no object. Calling a method on it, or passing it to most system methods, throws a `NullPointerException`.
- **Empty** means an object exists with nothing in it (an empty list, `''`, a new sObject with no fields set). Acting on it does not throw.
- A queried checkbox field is never null. A plain `Boolean` variable that was never assigned is null.
- `Map.get` returns null for a missing key.

Most redundant checks in Apex come from mixing these up. Before adding or keeping a check, decide which of the two can actually happen at that point.

## 2. Guard clauses

**Why:** nesting the main logic inside several `if` blocks pushes the important line far to the right and makes the exit conditions hard to see.

**Fix:** check the conditions that stop the method at the top and return (or throw) early, so the rest of the method runs only on valid input.

```apex
public static void syncAccount(Account account) {
    if (account != null) {
        if (account.Is_Active__c) {
            if (String.isNotBlank(account.External_Id__c)) {
                sendToErp(account);
            }
        }
    }
}
```

```apex
public static void syncAccount(Account account) {
    if (account == null || !account.Is_Active__c || String.isBlank(account.External_Id__c)) {
        return;
    }
    sendToErp(account);
}
```

**Balance:** several guards stacked at the top are good. `return` statements scattered through the middle of complex logic are not, because the reader cannot tell when the method stops. In a long validation, a single result variable updated by the checks and returned once can read better.

**Return or throw?** Return quietly when "nothing to do" is a normal outcome (an empty trigger batch, no matching records). Throw when the caller broke a contract it must not break (a required parameter is missing), so the bug shows up where it starts.

## 3. Validation helpers

- `String.isBlank` / `String.isNotBlank` cover null, empty and whitespace. Use them instead of `s == null || s == ''`.
- `isEmpty()` reads better than `size() == 0` and `size() > 0`.
- Before DML on a list the method built itself, check `if (!records.isEmpty())`. An empty DML costs no limits, but it does cost noticeably more CPU than the check.
- Use `containsKey` before `get` on a map you did not build yourself from a query.
- Validate parameters in a separate private method when the checks would otherwise bury the main logic.

## 4. Do not guard what cannot happen

**Why:** a null check on a list the method just created hides a bug if the list ever does become null, because the DML is skipped silently with no else branch.

**Rule:** do not null-check a collection or object you instantiated in the same method. Do null-check values that come from parameters, map lookups, relationship fields (`order.Account__r`) and optional configuration.

## 5. Safe navigation and null coalescing

- `??` is useful: it supplies a default (`contact.MailingCity = account.BillingCity ?? DEFAULT_CITY`).
- `?.` returns null when the left side is null. That often only moves the `NullPointerException` a few lines further down. Use it when null is a valid, handled outcome. Prefer a guard clause when null means "stop".
- `?.` and `??` together (`account?.BillingCity ?? DEFAULT_CITY`) are fine when the default is meaningful.

## 6. What to return when nothing is found

- A lookup of one record that finds nothing returns `null`, like `Map.get`.
- A method that returns records returns an empty list, like SOQL. Never return null for a list.
- Throw only for real failures, not for "not found".
- Never return an empty sObject as "not found", because callers cannot reliably tell it apart from a real record.

## 7. Catch blocks

**Why:** an empty or log-nothing catch turns a failure into silent wrong data.

**A catch must do at least one of:**
- log through the org's logger (in this repo, `Logger.error(new Log(e)...)`) with enough context to find the record;
- rethrow, or throw a more meaningful exception;
- recover deliberately, for example roll back to a savepoint and return a failure result.

**Signals:** `catch (Exception e) {}`, a catch that only calls `System.debug`, catching `Exception` around one statement whose specific exception type is known, and try/catch around code that cannot throw.

**Partial-success DML:** with `Database.update(records, false)`, inspect every `SaveResult` and log or report the failures. Ignoring the results is the same as an empty catch.

## 8. Atomic operations

**Rules of thumb:**
- An uncaught exception rolls back every DML in the transaction.
- A caught exception rolls back only the failing statement. Everything before it still commits.
- If several writes must succeed or fail together, say so in code: set a savepoint, do the writes, and roll back in the catch.

```apex
Savepoint beforeReassignment = Database.setSavepoint();
try {
    update opportunities;
    insert followUpTasks;
} catch (DmlException e) {
    Database.rollback(beforeReassignment);
    Logger.error(new Log(e).withClassName('AccountReassignment').withName('Reassignment Failed'));
    throw e;
}
```

**Signals of a hidden atomic process:** one business process split across several triggers (an account trigger updates opportunities, whose trigger creates tasks, whose trigger updates users). Nobody can tell whether a failure at the end should undo the start. Propose consolidating a truly atomic process into one deep method with a savepoint.

## 9. Cascading failures from trigger after-logic

**Why:** after-trigger logic that writes other objects runs in the same transaction as the original save. A validation rule on that other object can fail a save the user made for an unrelated reason.

**Decide per piece of after-logic:** is it part of the same business process as the record being saved?
- **Yes:** keep it synchronous and let a failure fail the save, with a clear error.
- **No:** propose isolating it so its failure cannot roll back the parent: a Queueable, a platform event, or Change Data Capture. Each needs good logging and must re-check its conditions when it runs, because records may have changed by then. Mind the async limits, especially when already in an async context.

**Context matters:** the same error may be right to show when a user saved the record directly, and wrong to let bubble up when the code runs several levels deep inside another process. Handle exceptions at the entry points (trigger handlers, controllers, batch `execute`, invocables), not in every helper.

## 10. Design the error away

Before adding a branch for an edge case, ask whether the semantics can make it a no-op instead. For example, a method that accepts an empty list and does nothing needs no guard in any caller, and a builder that ignores blank values needs no check per field. Fewer edge cases means fewer error paths to test.
