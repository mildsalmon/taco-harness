# Coding Principles

This document is the Single Source of Truth for coding principles applied across all taco-harness pipeline stages.

## 1. Polymorphism-Oriented OOP

Design with substitutability in mind. Favor composition and interfaces over deep inheritance trees.

### Core Rules
- **Composition > Inheritance**: Assemble behavior by composing small, focused objects rather than building deep class hierarchies
- **Strategy Pattern**: Extract varying behavior into interchangeable strategy objects instead of branching with if/else or switch
- **Template Method**: Define algorithm skeleton in a base, let subclasses override specific steps only
- **Dependency Inversion (DIP)**: Depend on abstractions (Protocol/ABC/Interface), never on concrete implementations
- **Open/Closed**: Classes are open for extension, closed for modification — add behavior by adding new types, not editing existing ones

### Checklist
- [ ] No class inherits more than 2 levels deep
- [ ] Behavior variations use Strategy or similar pattern, not conditional chains
- [ ] High-level modules depend on abstractions, not low-level modules
- [ ] New behavior can be added without modifying existing code
- [ ] Each class has a single reason to change (SRP)

### Anti-Patterns
- **God Class**: One class that knows and does everything
- **instanceof/type-check chains**: `if isinstance(x, A) ... elif isinstance(x, B)` — use polymorphic dispatch instead
- **Deep inheritance**: A → B → C → D → E hierarchy that is fragile and hard to reason about
- **Leaky abstraction**: Interface that exposes implementation details (e.g., `SQLUserRepository` instead of `UserRepository`)

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
- **Port**: Interface that the domain defines for what it *needs* (Driven Port) or what it *offers* (Driving Port)
  - Driving Port: Use cases the outside world can invoke (e.g., `CreateOrderUseCase`)
  - Driven Port: Services the domain needs (e.g., `OrderRepository`, `PaymentGateway`)
- **Adapter**: Concrete implementation of a Port (e.g., `PostgresOrderRepository`, `StripePaymentGateway`)
- **Dependency Direction**: Always inward. Adapters depend on Ports; Ports depend on Domain. Never the reverse
- **Domain purity**: Domain objects must be testable with zero infrastructure (no DB, no network, no filesystem)

### Directory Structure Example
```
src/
├── domain/           # Pure business logic
│   ├── models/       # Entities, Value Objects
│   ├── services/     # Domain services
│   └── ports/        # Port interfaces (Driving + Driven)
├── application/      # Use cases (orchestrate domain)
│   └── use_cases/
├── adapters/         # Infrastructure implementations
│   ├── inbound/      # REST controllers, CLI handlers, message consumers
│   └── outbound/     # DB repositories, external API clients, file storage
└── config/           # Wiring / dependency injection
```

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
