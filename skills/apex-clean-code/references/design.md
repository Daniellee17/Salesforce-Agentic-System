# Design: OOP, principles, coupling, cohesion and dependencies

Everything here is usually a **Proposal**, not a safe fix, because it changes class structure. Recommend it only when the code in scope shows a real need, and include a sketch of the target shape.

## 1. Encapsulation: expose behaviour, not state

**Why:** public fields, or getters and setters that only pass a private field through, let every caller depend on the internals, so any internal change breaks them.

**Fix:** expose operations that mean something (`applyDiscount(percent)`, `markProcessed()`) and keep the state private. Keep a plain property only when the class really is a data carrier (a wrapper returned to an LWC, a result DTO).

## 2. Inheritance, composition, interfaces and abstract classes

| Tool | Use it when | Avoid it when |
|---|---|---|
| Inheritance (`virtual` / `extends`) | there is a real "is a special kind of" family with shared behaviour and specialised steps | the subclass only wants to reuse a few helper methods |
| Composition (pass an object in) | a class "has a" collaborator such as a logger, a callout client or a calculator | never wrong as a default |
| Interface | several implementations must be swappable: strategies, test doubles, real boundaries | there is exactly one implementation and no test or boundary reason |
| Abstract class (template method) | several classes share an algorithm but differ in some steps, for example common re-queue and limit logic for Queueables | the shared part is one line |

**Signals:** a class extending a logger or utility class to get its methods; `instanceof` checks on a base type (the subclass breaks the parent's contract); an interface mirroring the one class that implements it.

**Polymorphism's real job** is to remove growing type-based `if` / `else` chains. If there is no such chain, and no test or boundary need, it is probably not needed.

## 3. Single responsibility

**Why:** when one class serves several groups of users or reasons to change, a change for one group can break another (a marketing change breaking support SLAs).

**Test:** list who asks for changes to this class. If the list spans unrelated business areas, propose splitting by area. Gather what changes together, and separate what changes for different reasons.

**Signals:** a class per object that has grown into a catch-all (`OpportunityService` with sales, marketing and support logic); frequent merge conflicts on the same class from unrelated stories.

## 4. Open for extension, closed for modification

Worth designing for only where variations are known to keep coming (new DML operations, new trigger actions, new integration partners). Then a new variation should add a class, not edit a central method. For stable logic this is over-engineering.

## 5. Small, focused interfaces

An interface should demand only what every implementer needs. Optional behaviour goes in a separate interface, the way batch Apex separates `Database.Stateful` and `Database.RaisesPlatformEvents` from `Database.Batchable`.

## 6. Dependency inversion

When a high-level class depends on a lower-level helper through an interface, shape the interface around what the high-level class needs, not around the helper's existing methods. On its own this adds little. It pays off together with dependency injection (section 10).

## 7. DRY, but not too early

**Why:** duplication means a change must be made in several places, and one gets missed. A wrong shared abstraction is worse, though: every caller is forced into a contract that fits none of them well.

**Rules:**
- Remove duplication once the shared concept is clear, usually after two or three copies.
- Remove it immediately when the copies must always change together (the same business rule, the same constant).
- Leave similar-looking code alone when the copies change for different reasons.
- A shared utility used everywhere becomes coupled to everything. Keep it small and stable.

## 8. YAGNI

Flag parameters nobody passes, interfaces with one implementation and no test use, factories for one type, configuration nobody sets, and "for future use" branches. Code for the requirement in the story.

## 9. Modularity, coupling and cohesion

**Coupling** is how much one piece must change when another changes. It is not only metadata references: two classes are also coupled when one requirement change forces both to change, even if neither references the other.

**Cohesion** is how closely the parts of a module serve one purpose. Coupled things should live close together, so the dependency is visible and changes stay in one place.

**Keep together when** the parts share data and are always used together, serve the same purpose, or cannot be understood without each other. **Split when** the split reduces the total complexity a reader faces. More, smaller classes are not automatically better.

**General-purpose over special-purpose:** a module that makes few assumptions about its callers is deeper and more reusable. A method that knows too much about its surroundings (a date helper that sets fields on records) is a design smell.

**Signals:**
- A `Utils` class of unrelated methods (low cohesion).
- A feature whose class, fields, validation and LWC logic are scattered with no visible link (hidden coupling). In this repo, sources sit in the default metadata folders, so mention the related metadata in the finding.
- A helper that only works after the caller has queried specific fields (long-distance coupling). Either let the helper query them, or make the required fields explicit in its signature or name.

## 10. Dependency injection and boundaries

**Dependency injection** is passing a collaborator in (usually through the constructor), typed as an interface, instead of creating it inside the class.

**Inject when the collaborator is:**
- a real boundary, where control leaves your code: callouts, the `Database` class (DML runs triggers, flows and validation rules you do not control), platform events, external services;
- something with real variations (different loggers, shipping providers, Git hosts);
- something tests must replace to stay fast and focused;
- something that must be chosen from configuration at runtime.

**Hard-code (instantiate directly) when** the collaborator is a simple utility with no variation, is easy to construct, and the interaction is a plain collaboration rather than a boundary.

```apex
public class OrderSync {
    private final ErpClient erp;

    public OrderSync() {
        this(new HttpErpClient());
    }

    @TestVisible
    private OrderSync(ErpClient erp) {
        this.erp = erp;
    }
}
```

The public constructor keeps callers unchanged, and the test can pass a stub `ErpClient`. Injection removes metadata coupling, not the coupling of the shared business process.

**Late binding** (`Type.forName(className).newInstance()` with the class name from custom metadata) gives the most flexibility, but a wrong name only fails at runtime. Propose it only when implementations must be swappable through configuration, and validate the name first.
