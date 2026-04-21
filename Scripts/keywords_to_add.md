# 번들 DB 확장 — 추가 키워드 300개 (Phase 1 큐레이션)

## 메타

- **목표 합계**: 300개 (현재 200개 → 500개로 확장)
- **카테고리 배분**: 동시성 40, 자료구조 50, 네트워크 46, DB 50, 패턴 50, 기타 64
- **현황**: 큐레이션만 완료. terms.json 갱신·API 호출은 Phase 2에서.
- **다음 단계 안내**: 이 파일을 입력으로 `Scripts/generate_db.py --keywords` 호출.

## ✅ 기존 200개 중복 검증 완료

검증 방법:
```bash
python3 -c "
import json, re
with open('DevEtym/DevEtym/Resources/terms.json') as f:
    data = json.load(f)
existing_kw = {d['keyword'] for d in data}
existing_alias = {a for d in data for a in d.get('aliases', [])}
with open('Scripts/keywords_to_add.md') as f:
    text = f.read()
new_kw = re.findall(r'^- ([a-z0-9][a-z0-9_-]*) —', text, re.MULTILINE)
print('새 키워드 개수:', len(new_kw))
print('중복 keyword:', set(new_kw) & existing_kw)
print('중복 alias 충돌:', set(new_kw) & existing_alias)
print('내부 중복:', [k for k in new_kw if new_kw.count(k) > 1])
"
```

기대 출력: `새 키워드 개수: 300`, 나머지 셋 모두 빈 결과.

기존 200개 keyword 목록은 `DevEtym/DevEtym/Resources/terms.json`에서 추출. 본 파일의 신규 키워드는 모두 그 목록과 다르며, 기존 alias 문자열과도 충돌하지 않음 (모든 신규 keyword가 영문 소문자/하이픈/숫자라 한글 alias와 자연 분리됨).

---

## 동시성 (40개)

- fork-join — 포크 조인, Fork-Join
- work-stealing — 워크 스틸링, Work Stealing
- green-thread — 그린 스레드, Green Thread
- event-loop — 이벤트 루프, Event Loop
- reactive — 리액티브, Reactive Programming
- backpressure — 백프레셔, 역압
- mailbox — 메일박스, 메시지함
- supervisor — 슈퍼바이저, 감독자
- generator — 제너레이터, 생성기
- yield — 일드, 양보
- read-write-lock — 읽기-쓰기 락, Read-Write Lock
- reentrant-lock — 재진입 락, Reentrant Lock
- cas — 컴페어 앤 스왑, Compare-And-Swap
- memory-fence — 메모리 펜스, Memory Fence
- happens-before — 해픈스 비포, Happens-Before
- memory-model — 메모리 모델, Memory Model
- thread-pool — 스레드 풀, Thread Pool
- pipeline — 파이프라인, Pipeline
- producer-consumer — 생산자-소비자, Producer-Consumer
- dining-philosophers — 식사하는 철학자, Dining Philosophers
- worker — 워커, 작업자
- continuation — 컨티뉴에이션, 연속
- goroutine — 고루틴, Goroutine
- lock-free — 락 프리, Lock-Free
- wait-free — 웨이트 프리, Wait-Free
- nonblocking — 논블로킹, Non-blocking
- thunk — 썽크, Thunk
- async-io — 비동기 입출력, Asynchronous I/O
- waitgroup — 웨이트 그룹, WaitGroup
- spawn — 스폰, 생성
- detach — 디태치, 분리
- interrupt — 인터럽트, 끼어들기
- signal — 시그널, 신호
- cooperative-multitasking — 협력형 멀티태스킹, Cooperative Multitasking
- preemptive-multitasking — 선점형 멀티태스킹, Preemptive Multitasking
- round-robin — 라운드 로빈, Round-Robin
- critical-section — 임계 영역, Critical Section
- busy-wait — 바쁜 대기, Busy-Wait
- pthread — 피스레드, POSIX Thread
- structured-concurrency — 구조적 동시성, Structured Concurrency

## 자료구조 (50개)

- doubly-linked-list — 이중 연결 리스트, Doubly Linked List
- circular-linked-list — 원형 연결 리스트, Circular Linked List
- fenwick-tree — 펜윅 트리, Binary Indexed Tree
- suffix-tree — 접미사 트리, Suffix Tree
- suffix-array — 접미사 배열, Suffix Array
- union-find — 유니온 파인드, Union-Find
- disjoint-set — 디스조인트 셋, Disjoint Set
- kd-tree — k-d 트리, K-D Tree
- quadtree — 쿼드트리, Quadtree
- octree — 옥트리, Octree
- r-tree — R 트리, R-Tree
- fibonacci-heap — 피보나치 힙, Fibonacci Heap
- binomial-heap — 이항 힙, Binomial Heap
- radix-tree — 래딕스 트리, Radix Tree
- patricia-tree — 패트리샤 트리, Patricia Tree
- rope — 로프, Rope
- treap — 트리앱, Treap
- splay-tree — 스플레이 트리, Splay Tree
- dag — 디에이지, Directed Acyclic Graph
- dfs — 깊이 우선 탐색, Depth-First Search
- bfs — 너비 우선 탐색, Breadth-First Search
- dijkstra — 다익스트라, Dijkstra Algorithm
- backtracking — 백트래킹, 되추적
- greedy — 그리디, 탐욕 알고리즘
- dynamic-programming — 동적 계획법, Dynamic Programming
- memoization — 메모이제이션, Memoization
- divide-and-conquer — 분할 정복, Divide and Conquer
- quicksort — 퀵 정렬, Quick Sort
- mergesort — 병합 정렬, Merge Sort
- heapsort — 힙 정렬, Heap Sort
- bubblesort — 버블 정렬, Bubble Sort
- radixsort — 기수 정렬, Radix Sort
- binary-search — 이진 탐색, Binary Search
- linear-search — 선형 탐색, Linear Search
- bitmap — 비트맵, Bitmap
- bitset — 비트셋, Bitset
- immutable — 이뮤터블, 불변
- mutable — 뮤터블, 가변
- lru-cache — 엘알유 캐시, Least Recently Used Cache
- lfu-cache — 엘에프유 캐시, Least Frequently Used Cache
- multimap — 멀티맵, MultiMap
- multiset — 멀티셋, MultiSet
- linked-hashmap — 링크드 해시맵, LinkedHashMap
- ordered-map — 오더드 맵, Ordered Map
- amortized — 분할 상환, Amortized Analysis
- hash-collision — 해시 충돌, Hash Collision
- open-addressing — 개방 주소법, Open Addressing
- chaining — 체이닝, Separate Chaining
- perfect-hash — 퍼펙트 해시, Perfect Hash
- b-plus-tree — B+ 트리, B-Plus Tree

## 네트워크 (46개)

- reverse-proxy — 리버스 프록시, Reverse Proxy
- forward-proxy — 포워드 프록시, Forward Proxy
- load-balancer — 로드 밸런서, Load Balancer
- nat — 냇, Network Address Translation
- dhcp — 디에이치씨피, Dynamic Host Configuration Protocol
- icmp — 아이씨엠피, Internet Control Message Protocol
- arp — 에이알피, Address Resolution Protocol
- mac-address — 맥 주소, Media Access Control Address
- subnet — 서브넷, Subnetwork
- cidr — 사이더, Classless Inter-Domain Routing
- ipv4 — 아이피브이4, IPv4
- ipv6 — 아이피브이6, IPv6
- mtu — 엠티유, Maximum Transmission Unit
- ttl — 티티엘, Time To Live
- cors — 코스, Cross-Origin Resource Sharing
- csrf — 씨에스알에프, Cross-Site Request Forgery
- xss — 엑스에스에스, Cross-Site Scripting
- sql-injection — 에스큐엘 인젝션, SQL Injection
- mitm — 중간자 공격, Man-In-The-Middle Attack
- ddos — 디도스, Distributed Denial of Service
- webhook — 웹훅, Webhook
- polling — 폴링, Polling
- long-polling — 롱 폴링, Long Polling
- server-sent-events — 서버 전송 이벤트, Server-Sent Events
- webrtc — 웹알티씨, Web Real-Time Communication
- mqtt — 엠큐티티, MQ Telemetry Transport
- amqp — 에이엠큐피, Advanced Message Queuing Protocol
- ftp — 에프티피, File Transfer Protocol
- sftp — 에스에프티피, SSH File Transfer Protocol
- ssh — 에스에스에이치, Secure Shell
- telnet — 텔넷, Telnet
- smtp — 에스엠티피, Simple Mail Transfer Protocol
- pop3 — 팝쓰리, Post Office Protocol 3
- imap — 아이맵, Internet Message Access Protocol
- graphql — 그래프큐엘, GraphQL
- soap — 소프, Simple Object Access Protocol
- http2 — 에이치티티피2, HTTP/2
- http3 — 에이치티티피3, HTTP/3
- quic — 큑, QUIC
- anycast — 애니캐스트, Anycast
- multicast — 멀티캐스트, Multicast
- broadcast — 브로드캐스트, Broadcast
- unicast — 유니캐스트, Unicast
- bgp — 비지피, Border Gateway Protocol
- ospf — 오에스피에프, Open Shortest Path First
- keep-alive — 킵얼라이브, Keep-Alive

## DB (50개)

- clustered-index — 클러스터드 인덱스, Clustered Index
- non-clustered-index — 논클러스터드 인덱스, Non-clustered Index
- composite-index — 복합 인덱스, Composite Index
- unique-constraint — 유니크 제약, Unique Constraint
- check-constraint — 체크 제약, Check Constraint
- not-null — 낫 널, NOT NULL Constraint
- raft — 래프트, Raft Consensus Algorithm
- having — 해빙, HAVING Clause
- group-by — 그룹 바이, GROUP BY
- order-by — 오더 바이, ORDER BY
- left-join — 레프트 조인, LEFT JOIN
- right-join — 라이트 조인, RIGHT JOIN
- inner-join — 이너 조인, INNER JOIN
- outer-join — 아우터 조인, OUTER JOIN
- cross-join — 크로스 조인, CROSS JOIN
- self-join — 셀프 조인, SELF JOIN
- subquery — 서브쿼리, Subquery
- cte — 씨티이, Common Table Expression
- window-function — 윈도우 함수, Window Function
- aggregation — 애그리게이션, Aggregation
- optimistic-lock — 낙관적 락, Optimistic Locking
- read-committed — 리드 커밋티드, Read Committed
- read-uncommitted — 리드 언커밋티드, Read Uncommitted
- repeatable-read — 리피터블 리드, Repeatable Read
- serializable — 시리얼라이저블, Serializable
- dirty-read — 더티 리드, Dirty Read
- phantom-read — 팬텀 리드, Phantom Read
- nonrepeatable-read — 논리피터블 리드, Non-repeatable Read
- wal — 웰, Write-Ahead Logging
- redo-log — 리두 로그, Redo Log
- undo-log — 언두 로그, Undo Log
- checkpoint — 체크포인트, Checkpoint
- savepoint — 세이브포인트, Savepoint
- two-phase-commit — 2단계 커밋, Two-Phase Commit
- cap-theorem — 캡 정리, CAP Theorem
- eventual-consistency — 결과적 일관성, Eventual Consistency
- base — 베이스, Basically Available Soft state Eventual consistency
- vacuum — 배큠, Vacuum
- analyze — 어낼라이즈, ANALYZE
- explain — 익스플레인, EXPLAIN
- query-plan — 쿼리 플랜, Query Plan
- query-optimizer — 쿼리 옵티마이저, Query Optimizer
- n-plus-one — 엔플러스원, N+1 Problem
- lazy-loading — 레이지 로딩, Lazy Loading
- eager-loading — 이거 로딩, Eager Loading
- connection-pool — 커넥션 풀, Connection Pool
- prepared-statement — 프리페어드 스테이트먼트, Prepared Statement
- sequence — 시퀀스, Sequence
- auto-increment — 오토 인크리먼트, Auto Increment
- uuid — 유유아이디, Universally Unique Identifier

## 패턴 (50개)

- dependency-injection — 의존성 주입, Dependency Injection
- inversion-of-control — 제어의 역전, Inversion of Control
- service-locator — 서비스 로케이터, Service Locator
- unit-of-work — 작업 단위, Unit of Work
- data-mapper — 데이터 매퍼, Data Mapper
- active-record — 액티브 레코드, Active Record
- value-object — 값 객체, Value Object
- entity — 엔티티, Entity
- domain-driven-design — 도메인 주도 설계, Domain-Driven Design
- ubiquitous-language — 유비쿼터스 언어, Ubiquitous Language
- bounded-context — 바운디드 컨텍스트, Bounded Context
- anti-corruption-layer — 부패 방지 계층, Anti-Corruption Layer
- layered-architecture — 계층형 아키텍처, Layered Architecture
- onion-architecture — 어니언 아키텍처, Onion Architecture
- microservices — 마이크로서비스, Microservices
- monolith — 모놀리스, Monolith
- soa — 에스오에이, Service-Oriented Architecture
- specification-pattern — 명세 패턴, Specification Pattern
- null-object — 널 객체, Null Object Pattern
- publish-subscribe — 발행-구독, Publish-Subscribe
- event-driven — 이벤트 기반, Event-Driven Architecture
- message-queue — 메시지 큐, Message Queue
- pipes-and-filters — 파이프 앤 필터, Pipes and Filters
- circuit-breaker — 서킷 브레이커, Circuit Breaker
- bulkhead — 벌크헤드, Bulkhead Pattern
- retry-pattern — 리트라이 패턴, Retry Pattern
- throttling — 스로틀링, Throttling
- rate-limiting — 레이트 리미팅, Rate Limiting
- sidecar — 사이드카, Sidecar Pattern
- ambassador — 앰배서더, Ambassador Pattern
- blue-green-deployment — 블루-그린 배포, Blue-Green Deployment
- canary-deployment — 카나리 배포, Canary Deployment
- feature-flag — 피처 플래그, Feature Flag
- strangler-fig — 스트랭글러 픽, Strangler Fig Pattern
- choreography — 코레오그래피, Choreography
- orchestration — 오케스트레이션, Orchestration
- mvi — 엠브이아이, Model-View-Intent
- flux — 플럭스, Flux Architecture
- functional-programming — 함수형 프로그래밍, Functional Programming
- object-oriented — 객체지향, Object-Oriented Programming
- solid — 솔리드, SOLID Principles
- dry — 드라이, Don't Repeat Yourself
- kiss — 키스, Keep It Simple Stupid
- yagni — 야그니, You Aren't Gonna Need It
- liskov-substitution — 리스코프 치환, Liskov Substitution Principle
- open-closed — 개방-폐쇄 원칙, Open-Closed Principle
- single-responsibility — 단일 책임, Single Responsibility Principle
- interface-segregation — 인터페이스 분리, Interface Segregation Principle
- dependency-inversion — 의존성 역전, Dependency Inversion Principle
- coupling — 결합도, Coupling

## 기타 (64개)

- linter — 린터, Linter
- formatter — 포매터, Formatter
- transpiler — 트랜스파일러, Transpiler
- assembler — 어셈블러, Assembler
- disassembler — 디스어셈블러, Disassembler
- decompiler — 디컴파일러, Decompiler
- ide — 아이디이, Integrated Development Environment
- repl — 레플, Read-Eval-Print Loop
- ast — 에이에스티, Abstract Syntax Tree
- lexer — 렉서, Lexer
- parser — 파서, Parser
- tokenizer — 토크나이저, Tokenizer
- bytecode — 바이트코드, Bytecode
- opcode — 옵코드, Operation Code
- assembly — 어셈블리, Assembly Language
- machine-code — 머신 코드, Machine Code
- cross-compile — 크로스 컴파일, Cross-Compile
- static-linking — 정적 링킹, Static Linking
- dynamic-linking — 동적 링킹, Dynamic Linking
- dll — 디엘엘, Dynamic-Link Library
- monorepo — 모노레포, Monorepo
- polyrepo — 폴리레포, Polyrepo
- submodule — 서브모듈, Submodule
- branch — 브랜치, Branch
- merge — 머지, Merge
- rebase — 리베이스, Rebase
- cherry-pick — 체리픽, Cherry-pick
- stash — 스태시, Stash
- pull-request — 풀 리퀘스트, Pull Request
- continuous-integration — 지속적 통합, Continuous Integration
- continuous-deployment — 지속적 배포, Continuous Deployment
- devops — 데브옵스, DevOps
- sre — 에스알이, Site Reliability Engineering
- observability — 관측가능성, Observability
- telemetry — 텔레메트리, Telemetry
- tracing — 트레이싱, Distributed Tracing
- logging — 로깅, Logging
- metrics — 메트릭스, Metrics
- profiling — 프로파일링, Profiling
- benchmark — 벤치마크, Benchmark
- fuzzing — 퍼징, Fuzz Testing
- mutation-testing — 뮤테이션 테스팅, Mutation Testing
- unit-test — 단위 테스트, Unit Test
- integration-test — 통합 테스트, Integration Test
- e2e-test — 이투이 테스트, End-to-End Test
- tdd — 티디디, Test-Driven Development
- bdd — 비디디, Behavior-Driven Development
- mock — 목, Mock
- stub — 스텁, Stub
- spy — 스파이, Spy
- fixture — 픽스처, Fixture
- sandbox — 샌드박스, Sandbox
- virtualization — 가상화, Virtualization
- hypervisor — 하이퍼바이저, Hypervisor
- orchestrator — 오케스트레이터, Orchestrator
- kubernetes — 쿠버네티스, Kubernetes
- docker — 도커, Docker
- namespace — 네임스페이스, Namespace
- cgroup — 씨그룹, Control Group
- syscall — 시스콜, System Call
- xml — 엑스엠엘, eXtensible Markup Language
- json — 제이슨, JavaScript Object Notation
- yaml — 야믈, YAML Ain't Markup Language
- protobuf — 프로토버프, Protocol Buffers
