# Methods: one thing, depth, subtasks and parameters

## 1. One level of abstraction per method

**Why:** a method that mixes business steps with low-level detail forces every reader to understand the detail to follow the business flow, and couples the two so a change to one can break the other.

**Levels, from high to low:**
1. Orchestration: the steps of a use case (validate, build, save, notify).
2. Business rules: decisions in business terms (is this a gold-tier partner).
3. Data access: queries and DML.
4. Mechanics: string building, parsing, date maths, crypto, JSON, map building.

**Signals:** a method that reads like a user story for five lines and then drops into string splitting or nested map building; a loop body that both decides and builds and saves.

**Fix:** keep the method at one level and move the lower-level block into a private method named for what it achieves (`buildExternalId`, `parseRecordIds`). If the mechanics are reusable across classes, propose a small utility class.

**"One thing" in practice:** a method may do several steps if they are all at the same level. Do not chase a single statement per method. Check three questions instead: is this block at a different level, should it be reusable, and can the method be tested easily as it is?

## 2. Extract real subtasks, not fragments

**Why:** a good subtask can be read, named and tested on its own. A bad split creates two methods that only work together and must be read side by side.

**A real subtask:**
- takes everything it needs as parameters and returns its result;
- has a name that tells the parent's reader enough to skip it;
- does not depend on hidden state the parent set up first.

**A wrong split:** the extracted method reads instance fields the parent filled in, must be called in a fixed order with another helper, or makes no sense without the parent. Merge it back or pass the state in explicitly.

```apex
private void setDefaults() {
    newUser.ProfileId = standardProfileId;
    newUser.Alias = firstName.left(1) + lastName.left(4);
}
```

```apex
private static User withDefaults(User user, Id profileId) {
    user.ProfileId = profileId;
    user.Alias = user.FirstName.left(1) + user.LastName.left(4);
    return user;
}
```

## 3. Depth over length

**Why:** length is a symptom, not the goal. Chopping a clear 30-line method into ten one-line pass-throughs raises the amount a reader must hold in their head.

**Prefer deep methods:** a simple signature hiding real work. A public method should give its callers a lot of value for little knowledge (they should not need to know call order, internal flags or which `null` to pass).

**Short methods are right when they:**
- give an action a name (`buildRelationshipKey(parentId, childId)` instead of a repeated concatenation);
- hide an internal detail callers should not depend on (`isBypassed(actionName)` instead of exposing the set);
- simplify an API (`beforeInsert(records)` wrapping a generic `run(operation, records, null)`).

**Long methods are fine when they** coordinate a sequence of well-named steps. The method then documents the order of execution. Do not split it just to meet a line count.

**Signals of shallow design:** pass-through methods that add nothing; a class whose public methods must be called in a set order; two classes that never work without each other.

## 4. Boolean and multiple parameters

**Why:** `doSomething(records, true, false)` is unreadable at the call site, and each Boolean usually splits the method into two behaviours.

**A Boolean parameter is acceptable when** there is only one, it refines the main behaviour at the same level of abstraction, and it is named for its effect (`allowPartialSuccess`, not `flag`).

**Otherwise:**
- If one Boolean switches between two clearly different behaviours, split into two methods with honest names.
- If there are several options, pass a small options class or an enum.
- If an option is unrelated to the method's job (for example "also write a debug log"), remove it from the signature and handle it elsewhere.

**Four or more parameters** usually means a missing concept. Group related values into a small class, or pass the record that already holds them. Do not just switch to `List<String>` positions, because that hides meaning.

## 5. Side effects

**Why:** a method that secretly does something its name does not promise (a callout, DML on another object, deleting child records, enqueuing a job) gets reused in places where that effect is harmful.

**Signals:** callouts or `System.enqueueJob` inside a method named for a calculation; a "validate" method that writes records; a branch diff that adds a new effect to an existing method without renaming it.

**Fix:** move the extra effect to its own method called explicitly by the orchestrator, or rename the method so the effect is visible. When the method is public, that is a Proposal.

## 6. Growing `if` / `switch` chains

**Why:** a chain that branches on a type or operation, and gains a branch with every requirement, becomes the most fragile place in the class.

**Steps, from light to heavy:**
1. Replace string comparisons with an enum so typos cannot compile.
2. Keep each `when` branch to a single call to a well-named method.
3. When branches keep being added, or each branch is a full variation of a process, propose a strategy: an interface with one class per variation and a `Map<EnumType, Interface>` lookup, so a new variation adds a class instead of editing the chain.

**Leave alone:** a small, stable set of branches. A strategy for two branches that have not changed in years is over-engineering.

```apex
switch on operation {
    when INSERTS { results = Database.insert(records, allOrNone); }
    when UPDATES { results = Database.update(records, allOrNone); }
}
```

```apex
private static final Map<Operation, DmlStep> STEPS_BY_OPERATION = new Map<Operation, DmlStep>{
    Operation.INSERTS => new InsertStep(),
    Operation.UPDATES => new UpdateStep()
};

List<Database.SaveResult> results = STEPS_BY_OPERATION.get(operation).run(records, allOrNone);
```

## 7. Bulk and limits inside methods

Clean code must stay bulk-safe. When splitting or extracting:
- Never move a query or DML into a helper that a loop then calls once per record.
- Prefer helpers that take and return collections (`List<Order__c>`, `Map<Id, SObject>`).
- Pass records rather than Ids when the caller already has them, so the helper cannot be called in a loop and query each time. The caller must then query every field the helper reads.
