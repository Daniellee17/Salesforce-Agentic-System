# Naming and conditional logic

Names are the main way this repo explains code, because comments are not allowed. A name has to carry the intent a comment would otherwise carry.

## 1. Names reveal intent

**Why:** the next developer decides whether to reuse, change or delete code from its name. A vague name forces them to read the whole method, and a misleading one makes them reuse it wrongly.

**Signals:** abbreviations (`acc`, `oppLst`, `tsk1`, `cs`), generic words (`data`, `info`, `temp`, `result`, `process`, `handle`, `doWork`), names that only state the type (`accountList`, `stringValue`), and method names that say *what* but not *why* (`createTasks` when the purpose is to notify new owners).

**Decide:** ask "if I read only this name in six months, do I know what it holds and why it exists?" If not, rename. Prefer the business concept over the mechanism: `notifyNewAccountOwners` survives a switch from Tasks to emails, while `createTasks` does not.

**Leave alone:** loop counters (`i`, `j`), the conventional `bc` / `sc` context parameters, and `e` in a short `catch`. Short-lived, low-impact variables do not need long names. A short-lived variable that changes behaviour (an all-or-none flag, a limit) still does.

```apex
for (Account a : accs) {
    if (a.Tier__c == 'Gold') {
        t.add(new Task(WhatId = a.Id, OwnerId = a.OwnerId));
    }
}
```

```apex
for (Account newAccount : newAccounts) {
    if (newAccount.Tier__c == GOLD_TIER) {
        welcomeCallTasks.add(new Task(WhatId = newAccount.Id, OwnerId = newAccount.OwnerId));
    }
}
```

## 2. Collections and maps

**Why:** names that state the collection type go stale when the type changes, and say nothing about which records are inside.

**Rules:**
- Lists and sets use the plural of what they hold, narrowed by meaning: `accounts`, `closedOpportunities`, `ordersToRelink`.
- Maps use `<values>By<key>`: `accountsById`, `contactsByAccountId`, `sapAccountsByExternalId`. Nested maps chain the keys: `lineItemsByProductIdByOrderId`.
- A set of Ids says whose Ids: `parentAccountIds`, not `ids`.
- Follow the surrounding file. If it consistently uses the singular map form (`accountById`), keep that. Consistency beats either convention.

## 3. Distinguish values of the same type

**Why:** `o1` and `o2` hide whether two records are the same record in two trigger states, a parent and a child, or two unrelated records. That difference decides whether the logic is right.

**Fix:** name the role: `oldOpportunity` / `newOpportunity`, `parentCase` / `childCase`, `sourceAccount` / `targetAccount`. The same applies to methods: `insertLeads` next to `createLeads` must say how they differ, for example `buildLeads` and `insertLeads`.

## 4. Names stay true

**Why:** when a requirement narrows what a variable holds, the old name now lies. `allContacts` that holds only last week's contacts invites a wrong reuse.

**Signals:** a branch diff that changes a query filter or the population logic of a collection without renaming it. Check this in every EXISTING file the branch touched.

## 5. Platform vocabulary

Use the names Salesforce developers already know: `TriggerHandler`, `beforeInsert`, `afterUpdate`, `Batch`, `Schedulable`, `Queueable`, `Selector`, `oldMap`, `newMap`. Do not invent synonyms (`RecordsProcessor.processAfterModification`).

## 6. Case and collisions

camelCase for variables, parameters and methods, PascalCase for classes and enums, UPPER_SNAKE_CASE for `static final` constants. Avoid a variable named exactly like a class or sObject (`Lead Lead`, `Contacts`) where it reads ambiguously.

## 7. Magic numbers and strings

**Why:** a bare `100`, `'Closed Won'` or `27` hides its meaning, cannot be searched for, and gets changed in one place but not the others.

**Fix:**
- A business value becomes a `private static final` constant with a meaningful name in the class that owns the rule.
- A governor limit uses the `Limits` class (`Limits.getLimitQueries()`), never a literal, because sync and async limits differ.
- A value used across classes belongs in one shared constant, not copied.
- Picklist values compared in several places become constants. Record type lookups go through `Schema` by developer name, never a hard-coded Id.

**Leave alone:** `0`, `1`, `-1` used as plain arithmetic, and literals whose meaning is obvious in place (`addDays(1)` for "tomorrow").

```apex
if (Limits.getQueries() < 100 && retries < 5) {
```

```apex
private static final Integer MAX_CALLOUT_RETRIES = 5;

if (Limits.getQueries() < Limits.getLimitQueries() && retries < MAX_CALLOUT_RETRIES) {
```

## 8. Name the condition

**Why:** a compound condition makes the reader evaluate the logic before they know the concept it stands for, and the same concept usually ends up copied with small differences elsewhere.

**Fix, in order of strength:**
1. A local Boolean with a concept name, when the condition is used once.
2. A private method that returns the Boolean, when it is used more than once in the class or needs sub-conditions.
3. A method on a shared class (for example an `AccountTier` or domain class), when other classes decide the same concept.

Booleans read as a question or a state: `isGoldTier`, `hasStageChanged`, `needsAccountLink`. Pick the form the file already uses.

```apex
if (acc.Is_Supplier__c != false && acc.Verification__c == 'Completed' && acc.AnnualRevenue > 100000) {
```

```apex
Boolean isVerifiedPartner = acc.Is_Supplier__c && acc.Verification__c == VERIFICATION_COMPLETED;
Boolean isGoldTier = acc.AnnualRevenue > GOLD_TIER_MIN_REVENUE;
if (isVerifiedPartner && isGoldTier) {
```

## 9. Negations and redundant comparisons

- Remove double negatives: `!= false` becomes the field itself, `!= true` becomes `!field`.
- `== true` on a queried checkbox is redundant, because checkbox fields are never null. On a plain `Boolean` variable that may be null, `== true` is a deliberate null guard: keep it, or make the variable non-null at its source.
- Prefer a positive name over negating a negative one: `isActive` rather than `!isInactive`.
- Turn `if (x) { return true; } return false;` into `return x;`.

## 10. When a name will not come

If you cannot find an honest name for a method or class, it probably does two things or sits in the wrong place. Report that as a design finding instead of inventing a vague name.
