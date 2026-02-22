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
적절한 상황에서 GoF 디자인 패턴을 활용한다. 단, 패턴 적용 자체가 목적이 되어선 안 되며 문제를 명확히 해결할 때만 사용한다.

- **Strategy**: 조건 분기(if/else, switch) 대신 교체 가능한 전략 객체로 행동 변형을 추출
- **Template Method**: 알고리즘 골격은 base에 정의하고, 구체 단계만 subclass에서 override
- **Observer**: 상태 변화를 다수의 의존 객체에 알려야 할 때. 직접 호출 대신 이벤트 기반 통지
- **Factory Method / Abstract Factory**: 객체 생성 로직을 캡슐화하여 구체 클래스 의존을 제거
- **Decorator**: 기존 객체를 감싸서 동적으로 책임을 추가. 상속 없이 기능 확장
- **Adapter**: 호환되지 않는 인터페이스를 변환하여 기존 코드와 협력 가능하게 만듦

이 외의 패턴(Composite, Command, State, Proxy 등)도 상황에 맞으면 자유롭게 사용한다.

### Core Rules
- **Composition > Inheritance**: Assemble behavior by composing small, focused objects rather than building deep class hierarchies
- **Program to interfaces**: Declare dependencies as abstract types; swap implementations freely
- **Encapsulate what varies**: Identify what changes and isolate it behind an interface

### Checklist
- [ ] 다단계 상속(3+ levels)은 가급적 지양한다. 단, Template Method 등 명확한 이유가 있으면 허용하되 해당 이유를 주석으로 남긴다
- [ ] Behavior variations use Strategy or similar pattern, not conditional chains
- [ ] High-level modules depend on abstractions, not low-level modules (DIP)
- [ ] New behavior can be added without modifying existing code (OCP)
- [ ] Each class has a single reason to change (SRP)
- [ ] Subtypes are substitutable for their parent types without side effects (LSP)
- [ ] No client is forced to depend on methods it does not use (ISP)

### Anti-Patterns
- **God Class**: One class that knows and does everything
- **instanceof/type-check chains**: `if isinstance(x, A) ... elif isinstance(x, B)` — use polymorphic dispatch instead
- **Deep inheritance without justification**: A → B → C → D → E hierarchy that is fragile and hard to reason about. 상속이 필요하면 이유를 명시하고 가능한 얕게 유지
- **Leaky abstraction**: Interface that exposes implementation details (e.g., `SQLUserRepository` instead of `UserRepository`)
- **Pattern overuse**: 단순한 문제에 불필요한 패턴을 적용하여 복잡도만 높이는 경우

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
- **Port**: Application layer가 정의하는 인터페이스. 외부와의 경계를 명시
  - Driving (Inbound) Port: 외부가 애플리케이션을 호출하는 인터페이스 (e.g., `CreateOrderUseCase`)
  - Driven (Outbound) Port: 애플리케이션이 외부에 요청하는 인터페이스 (e.g., `OrderRepository`, `PaymentGateway`)
- **Adapter**: Port의 구체 구현체 (e.g., `PostgresOrderRepository`, `StripePaymentGateway`)
- **Dependency Direction**: Always inward. Adapters → Application(Ports) → Domain. Never the reverse
- **Domain purity**: Domain objects must be testable with zero infrastructure (no DB, no network, no filesystem)

### Directory Structure Example
```
src/
├── domain/              # Pure business logic
│   ├── models/          # Entities, Value Objects
│   └── services/        # Domain services
├── application/         # Application layer (ports + use cases)
│   ├── inbound/         # Driving side
│   │   ├── ports/       # Driving port interfaces (e.g., CreateOrderUseCase)
│   │   └── usecases/    # Use case implementations
│   └── outbound/        # Driven side
│       └── ports/       # Driven port interfaces (e.g., OrderRepository)
├── adapters/            # Infrastructure implementations
│   ├── inbound/         # Driving adapters (REST controllers, CLI handlers)
│   └── outbound/        # Driven adapters (DB repositories, API clients)
└── config/              # Wiring / dependency injection
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
