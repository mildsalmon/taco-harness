# Coding Principles

This document is the Single Source of Truth for coding principles applied across all taco-harness pipeline stages.

## 1. Polymorphism-Oriented OOP

Design with substitutability in mind. Favor composition and interfaces over deep inheritance trees.

### SOLID Principles
- **S — Single Responsibility (SRP)**: Each class has one reason to change. If a class handles both validation and persistence, split it
- **O — Open/Closed (OCP)**: Open for extension, closed for modification — add behavior by adding new types, not editing existing ones
- **L — Liskov Substitution (LSP)**: Subtypes must be usable wherever their parent type is expected without breaking correctness. If overriding a method changes the contract, the hierarchy is wrong
- **I — Interface Segregation (ISP)**: Clients should not depend on methods they don't use. Prefer small, focused interfaces over fat ones (e.g., `Readable` + `Writable` over `ReadWriteStorage`)
- **D — Dependency Inversion (DIP)**: Depend on abstractions (Protocol/ABC/Interface), never on concrete implementations. High-level modules define the interface; low-level modules implement it

### Design Patterns
Use GoF design patterns when they clearly solve a problem. Applying a pattern should never be the goal itself — only use one when it simplifies the design.

- **Strategy**: Extract varying behavior into interchangeable strategy objects instead of branching with if/else or switch
- **Template Method**: Define the algorithm skeleton in a base class; let subclasses override specific steps only
- **Observer**: Notify multiple dependents of state changes via events instead of direct calls
- **Factory Method / Abstract Factory**: Encapsulate object creation to eliminate dependency on concrete classes
- **Decorator**: Wrap an object to add responsibilities dynamically without inheritance
- **Adapter**: Convert an incompatible interface so existing code can collaborate with it

Other patterns (Composite, Command, State, Proxy, etc.) are equally valid when the situation calls for them.

### Core Rules
- **Composition > Inheritance**: Assemble behavior by composing small, focused objects rather than building deep class hierarchies
- **Program to interfaces**: Declare dependencies as abstract types; swap implementations freely
- **Encapsulate what varies**: Identify what changes and isolate it behind an interface

### Checklist
- [ ] Avoid multi-level inheritance (3+ levels). Allowed when clearly justified (e.g., Template Method), but document the reason in a comment
- [ ] Behavior variations use Strategy or similar pattern, not conditional chains
- [ ] High-level modules depend on abstractions, not low-level modules (DIP)
- [ ] New behavior can be added without modifying existing code (OCP)
- [ ] Each class has a single reason to change (SRP)
- [ ] Subtypes are substitutable for their parent types without side effects (LSP)
- [ ] No client is forced to depend on methods it does not use (ISP)

### Anti-Patterns
- **God Class**: One class that knows and does everything
- **instanceof/type-check chains**: `if isinstance(x, A) ... elif isinstance(x, B)` — use polymorphic dispatch instead
- **Deep inheritance without justification**: A → B → C → D → E hierarchy that is fragile and hard to reason about. If inheritance is needed, state the reason explicitly and keep it as shallow as possible
- **Leaky abstraction**: Interface that exposes implementation details (e.g., `SQLUserRepository` instead of `UserRepository`)
- **Pattern overuse**: Applying unnecessary patterns to simple problems, adding complexity without benefit

---

## 2. Kent Beck Style

Write code that communicates intent clearly. Keep it simple, prove it with tests.

### Core Rules
- **Simple Design 4 Rules** (in priority order):
  1. Passes all tests
  2. Reveals intention — code reads like prose
  3. No duplication (DRY, but only after the pattern is clear)
  4. Fewest elements — remove anything that doesn't serve rules 1-3
- **Small Methods**: 5-15 lines. If longer, extract with an intention-revealing name
- **Intention-Revealing Names**: Method/variable names describe *what*, not *how* (`calculateShippingCost`, not `calc`)
- **TDD**: Red (failing test) → Green (minimal pass) → Refactor (clean up)
- **YAGNI**: Do not build for hypothetical future requirements. Build what is needed now

### Checklist
- [ ] Every public method has a test
- [ ] No method exceeds ~15 lines
- [ ] Names describe intent without needing comments
- [ ] No speculative generality (unused abstractions, config flags for non-existent features)
- [ ] Duplication removed only when the pattern repeats 3+ times

### Anti-Patterns
- **Premature Abstraction**: Creating a framework/utility for a one-time operation
- **Comment-Dependent Code**: Code that only makes sense with extensive comments — rename and restructure instead
- **Speculative Generality**: Building plugin systems, feature flags, or extension points nobody asked for
- **Long Method**: A method doing 5 things — split into focused steps
- **Dead Code**: Commented-out code, unused parameters, unreachable branches

---

## 3. Hexagonal Architecture

Isolate domain logic from infrastructure. The domain is the center; everything else is a plug-in.

### Core Rules
- **Domain (Core)**: Pure business logic. No imports from frameworks, DB drivers, HTTP libraries, or external services
- **Port**: Interface defined by the application layer. Marks the boundary between inside and outside
  - Driving (Inbound) Port: Interface that the outside world uses to invoke the application (e.g., `CreateOrderUseCase`)
  - Driven (Outbound) Port: Interface that the application uses to request external services (e.g., `OrderRepository`, `PaymentGateway`)
- **Adapter**: Concrete implementation of a Port (e.g., `PostgresOrderRepository`, `StripePaymentGateway`)
- **Dependency Direction**: Always inward. Adapters → Application(Ports) → Domain. Never the reverse
- **Domain purity**: Domain objects must be testable with zero infrastructure (no DB, no network, no filesystem)

### Directory Structure Example
```
src/
├── domain/              # Pure business logic (no framework imports)
│   ├── models/          # Entities, Value Objects
│   └── services/        # Domain services (core business rules)
├── application/         # Application layer (orchestration)
│   ├── ports/
│   │   ├── inbound/     # Driving port interfaces (e.g., CreateOrderUseCase)
│   │   └── outbound/    # Driven port interfaces (e.g., OrderRepository)
│   └── services/        # Application services (implement inbound ports,
│                        #   orchestrate domain services, use outbound ports)
├── adapters/            # Infrastructure implementations
│   ├── inbound/         # Driving adapters (REST controllers, CLI handlers)
│   └── outbound/        # Driven adapters (DB repositories, API clients)
└── config/              # Wiring / dependency injection
```

### Call Flow
```
Adapter(inbound) → Port(inbound) → Application Service → Domain Service
                                                        ↘ Port(outbound) → Adapter(outbound)
```

- **Application Service**: Implements an inbound port. Orchestrates the use case by calling domain services for business logic and outbound ports for external dependencies. Contains no business rules itself
- **Domain Service**: Pure business logic. No knowledge of ports, adapters, or infrastructure

### Checklist
- [ ] Domain module has zero infrastructure imports
- [ ] Every external dependency is behind a Port interface
- [ ] Adapters implement Port interfaces, not the other way around
- [ ] Use cases orchestrate domain objects, not infrastructure directly
- [ ] Domain can be tested with in-memory fakes (no Docker, no real DB)

### Anti-Patterns
- **Domain-Infrastructure Coupling**: Domain model importing `sqlalchemy`, `requests`, `express`, etc.
- **Adapter Leak**: Business logic living inside a REST controller or DB repository
- **Missing Port**: Domain calling an external service directly without an interface boundary
- **Outward Dependency**: Domain module depending on an adapter module
- **Fat Use Case**: Use case that contains business rules instead of delegating to domain services
