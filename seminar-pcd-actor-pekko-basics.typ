#import "@preview/touying:0.6.3": *
#import themes.metropolis: *
#import "@preview/ctheorems:1.1.3": *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "utils.typ": *

#show: codly-init.with()
#codly(
  languages: codly-languages,
  zebra-fill: luma(245),
  display-icon: false,
  display-name: false,
  number-placement: "outside",
  inset: 0.35em,
)

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => self.info.institution,
  config-common(
    show-bibliography-as-footnote: bibliography(title: none, "bibliography.bib"),
  ),
  config-info(
    title: [Apache Pekko Introduction],
    subtitle: [Concurrent and Distributed Programming Course],
    author: author_list(
      (
        (first_author("Nicolas Farabegoli"), "nicolas.farabegoli@unibo.it"),
      ),
    ),
    date: datetime.today().display("[day] [month repr:long] [year]"),
    institution: [Department of Computer Science and Engineering (DISI) --- University of Bologna],
  ),
  config-colors(
    primary: rgb("#eb811b"),
    primary-light: rgb("#d6c6b7"),
    secondary: rgb("#23373b"),
    neutral-lightest: rgb("#fafafa"),
    neutral-dark: rgb("#23373b"),
    neutral-darkest: rgb("#23373b"),
  ),
  config-methods(
    init: (self: none, body) => {
      set text(font: "Fira Sans", weight: "light", size: 18pt)
      show math.equation: set text(font: "Fira Math")

      show raw: set text(size: 1em, font: "JetBrains Mono")
      // set raw(syntaxes: "Scala3/Scala 3.sublime-syntax")
      show link: set text(
        font: "JetBrains Mono",
        fill: rgb("#eb811b"),
        // weight: "medium",
      )

      show bibliography: set text(size: 0.75em)
      show footnote.entry: set text(size: 0.75em)
      set strong(delta: 200)
      set par(justify: true)
      body
    }
  )
)

// #set text(font: "Fira Sans", weight: "light", size: 16pt)
// #show math.equation: set text(font: "Fira Math")

// #show raw.where(block: true): set text(size: 1em, font: "JetBrains Mono")
// #show raw.where(block: false): set text(size: 16pt, font: "JetBrains Mono")

// #show bibliography: set text(size: 0.75em)
// #show footnote.entry: set text(size: 0.75em)
// #set par(justify: true)

#title-slide(
  // extra: [
  //   #note-block(
  //     [Migration note],
  //     [
  //       This deck reorganizes an older Akka-based seminar into a Pekko-first narrative.
  //       Historical Akka names appear only when they help recognize legacy material.
  //     ],
  //   )
  // ],
)

#slide(title: [Agenda])[
  #feature-block(
    [Today in one pass],
    [
      - Why the actor model still matters for concurrent software
      - What Apache Pekko provides on the JVM
      - Typed actors, lifecycle, supervision, and interaction patterns
      - Practical techniques: stash, FSMs, blocking isolation, discovery
      - Testing actor behavior in isolation and in a real actor system
      - Common mistakes, migration notes, and where to go next
    ],
  )
]

= Introduction

== Typical distributed system challenges

#components.side-by-side[
  #warning-block("Components crash")[
    #bold[Failures are the norm], not the exception.
  ]
][
  #warning-block("Messages get lost")[
    Messages can be #bold[lost], #bold[delayed], or #bold[duplicated].
  ]
][
  #warning-block("Network instability")[
    #bold[Latency], #bold[partitions], and #bold[topology changes].
  ]
]

#uncover("2")[
  #feature-block("Designing with those in mind")[
    These problems occurs regularly in distributed systems, so we need to design with them in mind.
  ]
]

== Why actors?

=== Easier concurrency
  The actor model provides a level of abstraction that makes it *easier* to write correct *concurrent and distributed* software.

=== Asynchronous messages
  Actors communicate *through asynchronous* messages, which #bold[decouples] the sender and receiver and allows for more *flexible* and *scalable* designs.

=== Explicit protocols
  The actor model encourages the use of *explicit protocols*, which can improve the clarity and maintainability of the code.

== Apache Pekko

#components.side-by-side(columns: (2fr, 1fr), gutter: 2em)[

  === Toolkit overview

  Apache Pekko is an open-source toolkit for building *concurrent*, *distributed*,
  and *resilient* message-driven applications on the JVM.

  It carries forward the #bold[actor-based] programming model, offers typed and classic APIs,
  and integrates modules for clustering, streams, persistence, and testing.

  #note-block(
    [Historical note],
    [
      Many older slides, blog posts, and repositories still say _Akka_.
      When migrating code, the main change is usually from `akka.*` / `com.typesafe.akka`
      to `org.apache.pekko` / `pekko.*`, plus updated dependency coordinates.
    ],
  )
][
  #figure(image("images/pekko-logo.png", height: 50%))
]

== Useful links

Website: #link("https://pekko.apache.org/")[pekko.apache.org/]

Documentation: #link("https://pekko.apache.org/docs/pekko/current/")[pekko.apache.org/docs/pekko/current/]

#note-block("Pekko API and DSL")[
  Pekko provides APIs for developing actor-based systems with *Java* and *Scala* DSLs.

  ```scala Pekko Typed``` new and type-safe API \
  ```scala Pekko Classic``` legacy API, still supported but not recommended for new code
]

== Core modules and ecosystem

```scala
"org.apache.pekko" %% "pekko-actor-typed" % PekkoVersion
```
Provides basic support for typed actors and actor systems.

```scala
"org.apache.pekko" %% "pekko-remote" % PekkoVersion
```
Remoting enables actors that live on different computers to seamlessly exchange messages. While distributed as a JAR artifact, Remoting resembles a module more than it does a library.

```scala
"org.apache.pekko" %% "pekko-cluster-typed" % PekkoVersion
```
Clustering gives you the ability to organize these into a “meta-system” tied together by a membership protocol

```scala
"org.apache.pekko" %% "pekko-cluster-sharding-typed" % PekkoVersion
```
Sharding is a pattern that mostly used together with Persistence to balance a large set of persistent entities

```scala
"org.apache.pekko" %% "pekko-cluster-singleton" % PekkoVersion
```
While this undeniably introduces a common bottleneck for the whole cluster that limits scaling, there are scenarios where the use of this pattern is unavoidable

```scala
"org.apache.pekko" %% "pekko-persistence-typed" % PekkoVersion
```
Persistence provides patterns to enable actors to persist events that lead to their current state.

```scala
"org.apache.pekko" %% "pekko-stream" % PekkoVersion
```
Streams provide a higher-level abstraction on top of actors that simplifies writing such processing networks, handling all the fine details in the background and providing a safe, typed, composable programming model.

= Actor Foundations

== Actor Anatomy

*Actors* are entities that #bold[encapsulate] #underline[state] and #underline[behavior] and interact solely through *asynchronous message passing*.

/ Behavior: upon message arrival, and actor can:
  - Sends a finite number of messages to other actors
  - Creates a finite number of child actors
  - (must) Specify the next behavior to handle the next message

/ Encapsulation: An actor is exposed to the outside through the ```scala ActorRef[T]```

Actors are #bold[logical] entities, decoupled by physical concurrency. An actor is a lightweight object (\~300 bytes) that can be created in large numbers, and the runtime schedules them on a pool of threads.

== Actor Architecture

An _Actor_ in Pekko always belongs to a *parent*.

Actors are created by ```scala ActorContext.spawn()``` and the #underline[creator] is the *parent* of the new actor.

#figure(image("images/actor-graph.png", height: 60%))

- `/` is the #bold[root guardian], which supervises the system guardian and the user guardian.
- `/system` is the #bold[system guardian], which supervises system actors created by Pekko modules.
- `/user` is the #bold[user guardian], which supervises all actors created by #underline[user code].

#slide[
  Printing the ```scala ActorRef``` shows the hierarchy path.

  #codly(
    header: [`basics / io.github.nicolasfara.es00.ActorHierarchyExample.scala`],
    header-cell-args: (align: center, ),
  )
  ```scala
  class PrintMyActorRef(context: ActorContext[String]) extends
    AbstractBehavior[String](context) {

    override def onMessage(msg: String): Behavior[String] =
      msg match {
        case "printit" =>
          val secondRef = context.spawn(Behaviors.empty[String], "second-actor")
          println(s"Second: $secondRef")
          this
      }
  }
  ```
]

== Pekko Actor System

An *Actor System* is a hierarchical group of actors which share common configuration, including #bold[dispatchers], #bold[mailboxes], and #bold[addresses]. It is the root of the actor hierarchy and provides the main entry point for creating actors.

#warning-block("Heavyweight structure")[
  It will allocate and manage #bold[1..N threads], and it is recommended to have one actor system per logical application boundary.
]

=== Hierarchical structure

- Splitting problems into smaller pieces
- Handling failures
- *Supervision model* (ispired by Erlang's "let it crash" philosophy)

== Actor systems, refs, and paths
#feature-block(
  [Three ideas to keep],
  [
    - `ActorSystem[T]` is the runtime root: create it once per logical application boundary.
    - Actors live in a #bold[hierarchy], with user actors supervised 
    - `ActorRef[T]` is the typed capability you share to let others send protocol messages.
  ],
)

#note-block(
  [Path intuition],
  [
    - An actor path names a position in the hierarchy, even when no actor is currently running there.
    - A reference points to a concrete live actor incarnation at that path.
    - Ordering is local: guaranteed for one sender and one receiver pair, not across the whole system.
  ],
)

// == Mailboxes, isolation, and throughput
// #feature-block(
//   [Operational intuition],
//   [
//     - Actors are logical concurrency units; dispatchers decide which threads run them.
//     - Lightweight actors scale because most actors are inactive most of the time.
//     - Message passing removes lock sharing, but protocol design still matters.
//     - At-most-once delivery means failures and retries belong in the protocol or infrastructure.
//   ],
// )
// #v(0.5em)
// #warning-block(
//   [Important boundary],
//   [
//     Actor isolation does not magically remove back-pressure, overload, or failure handling.
//     It gives you a disciplined place to model them.
//   ],
// )

= Typed API

== Getting started with Pekko Typed
```scala
val scala3Version = "3.7.4"
val PekkoVersion = "1.4.0"

libraryDependencies ++= Seq(
  "org.apache.pekko" %% "pekko-actor-typed" % PekkoVersion,
  "com.typesafe.scala-logging" %% "scala-logging" % "3.9.6",
  "ch.qos.logback" % "logback-classic" % "1.5.32"
  "org.apache.pekko" %% "pekko-actor-testkit-typed" % PekkoVersion % Test,
  "org.scalatest" %% "scalatest" % "3.2.20" % Test,
)
```

Code repository with examples:

#fa-github() #h(0.3em) #link("https://github.com/nicolasfara/seminar-pcd-actor-pekko-code")

== Core typed abstractions
#components.side-by-side(columns: (1fr, 1fr), gutter: 12pt)[
  #feature-block([`Behavior[T]`], [
    Describes how an actor handles one message of type `T`.
  ])
][
  #feature-block([`ActorRef[T]`], [
    Typed capability for sending messages in protocol `T`.
  ])
]
#v(0.5em)
#components.side-by-side(columns: (1fr, 1fr), gutter: 12pt)[
  #feature-block([`ActorSystem[T]`], [
    Runtime root and entry point of the application.
  ])
][
  #feature-block([`ActorContext[T]`], [
    Logging, spawning, adapters, scheduling hooks, and services.
  ])
]

== `Behavior[T]`: the actor logic
```scala
object Counter:
  enum Command:
    case Tick

  def apply(current: Int): Behavior[Command] =
    Behaviors.receiveMessage:
      case Command.Tick => Counter(current + 1)
```

#feature-block(
  [Why it matters],
  [
    - A `Behavior[T]` is the definition of how one actor reacts to messages of type `T`.
    - Returning a new behavior is how we model state changes in the functional style.
    - `Behaviors.same`, `Behaviors.stopped`, and recursive behaviors are the common building blocks.
  ],
)

== `ActorRef[T]`: the communication capability
```scala
object Counter:
  enum Command:
    case Tick
    case Get(replyTo: ActorRef[Int])

// somewhere else
counterRef ! Counter.Command.Tick
counterRef ! Counter.Command.Get(replyTo = probe.ref)
```

#note-block(
  [What to remember],
  [
    - An `ActorRef[T]` is the only public handle you need to interact with an actor.
    - The type parameter is the protocol: if a message is not in `T`, it cannot be sent.
    - Passing references around is how actors discover collaborators and where to send replies.
  ],
)

== `ActorSystem[T]`: the runtime root
```scala
@main def runCounter(): Unit =
  val system = ActorSystem(Counter(0), "counter-system")
  system ! Counter.Command.Tick
```

#feature-block(
  [Operational role],
  [
    - `ActorSystem[T]` starts the top-level behavior and owns the runtime infrastructure.
    - It manages dispatchers, scheduling, configuration, and the root guardians of the hierarchy.
    - In practice, we usually create one actor system per application or bounded subsystem.
  ],
)

== `ActorContext[T]`: the actor toolbox
```scala
def apply(): Behavior[Command] = Behaviors.setup: context =>
  val worker = context.spawn(Worker(), "worker")
  context.log.info("Worker started: {}", worker)
  Behaviors.receiveMessage:
    case Start =>
      worker ! Worker.Command.Run
      Behaviors.same
```

#feature-block(
  [Common uses],
  [
    - `ActorContext[T]` gives access to services that only make sense from inside an actor.
    - Typical operations are `spawn`, `watch`, logging, adapters, and scheduling-related helpers.
    - Keep the context local to the actor: do not treat it as a dependency to pass everywhere.
  ],
)

== Functional Style

#feature-block("Actor as a function")[
  An *actor* can be expressed as a #bold[function] that takes the current state and returns a behavior for the next message. This is the most common style in Pekko Typed, and it fits well with #underline[immutable state] and #underline[finite-state machines.]
]

```scala
object CounterActor:
  enum Cmd:
    case Tick

  def apply(from: Int, to: Int): Behavior[Cmd] = Behaviors.receive: (_, message) =>
    message match
      case Tick if from < to => CounterActor(from + 1, to)
      case _ => Behaviors.stopped
```

== Object-oriented style

#feature-block("Actor as an object")[
  For actors with complex mutable state, it can be more readable to use an object-oriented style and keep the state in mutable fields. This is a valid choice as long as the #bold[mutable state is properly encapsulated] and *not shared* outside the actor.
]

```scala
class Counter(context: ActorContext[Command], var from: Int, val to: Int) extends
  AbstractBehavior[Command](context):
    def onMessage(msg: Command): Behavior[Command] = msg match
      case Command.Tick if from < to =>
        context.log.info(s"Counter: $from")
        from += 1
        this
      case _ => Behaviors.stopped	
```

= Actor Lifecycle

== Actor creation and stopping
#feature-block(
  [Actor lifecycle basics],
  [
    - Actors are created when spawned: ```scala context.spawn(behavior, "name")```
    - Actors are stopped when they return ```scala Behaviors.stopped```
    - When a parent stops, #bold[all children are recursively stopped] before the parent's `PostStop` signal
  ],
)
#v(0.5em)
#warning-block(
  [Resource cleanup],
  [
    This hierarchical stopping behavior #bold[greatly simplifies resource cleanup] and helps avoid resource leaks from open sockets, files, and other concurrent resources.
  ],
)

== Actor creation

=== The root guardian
Create the *root user guardian* with ```scala ActorSystem(behavior, "name")```:

```scala
ActorSystem(Behaviors.setup(new MyRoot(_)), "mysystem")
```

=== Child actors
Create child actors with ```scala ActorContext[T].spawn(behavior, "name")```:

```scala
Behaviors.setup { context =>
  val child = context.spawn(someBehavior(), "child")
  context.log.info(s"Child created: $child")
  Behaviors.empty[String]
}
```

== Stopping patterns
#components.side-by-side(columns: (1fr, 1fr), gutter: 12pt)[
  #feature-block([Self-stopping], [
    Return `Behaviors.stopped` when the actor is done or in response to a user-defined stop message. This is the recommended pattern.
  ])
][
  #feature-block([Stopping children], [
    Call `context.stop(childRef)` from the parent. You cannot stop arbitrary (non-child) actors this way.
  ])
]

== Lifecycle signals: PostStop
#feature-block(
  [```scala PostStop``` signal],
  [
    Sent just after the actor has been stopped. No messages are processed after this point, but cleanup logic can be run here.
  ],
)
#v(0.5em)
```scala
override def onSignal: PartialFunction[Signal, Behavior[String]] =
  case PostStop =>
    context.log.info("Actor stopped, cleanup running")
    this
```
#note-block(
  [Strict ordering],
  [
    All ```scala PostStop``` signals of children are processed #bold[before] the ```scala PostStop``` signal of the parent.
  ],
)

== Lifecycle example: parent and child
#codly(
  header: [`basics / io.github.nicolasfara.es00.basics.ActorLifecycleExample.scala`],
  header-cell-args: (align: center, ),
)
```scala
object StartStopActor:
  def apply(): Behavior[String] = Behaviors.setup: context =>
    context.log.info(s"Actor ${context.self} started")
    val _ = context.spawn(ChildActor(), "child-actor")
    Behaviors.receiveMessage[String]:
      case "stop" => Behaviors.stopped
      case _      => Behaviors.same
object ChildActor:
  def apply(): Behavior[String] = Behaviors.setup: context =>
    context.log.info(s"Actor ${context.self} started")
    Behaviors.receiveSignal:
      case (ctx, PostStop) =>
        context.log.info(s"Actor ${ctx.self} stopping")
        Behaviors.same
```

== Lifecycle execution order
When we send `"stop"` to the first actor:

```
first started       // first actor created
second started      // child spawned
second stopped      // child stops first
first stopped       // then parent stops
```

#feature-block(
  [Key insight],
  [
    The #bold[strict parent-child ordering] ensures that children always clean up before their parents,
    preventing orphaned resources and simplifying resource management.
  ],
)

== Supervision

#feature-block("Validation error vs failure")[
  / Validation error: should be modeled as part of the protocol
  / Failure: an unexpected exception that should be handled by the supervision strategy.
  
  "_Let it crash_" is the recommended approach: if an actor fails, it should be stopped and restarted in a clean state by #bold[its parent].
]

#warning-block("Default failure strategy")[
  Actors are #bold[stopped by default] if an exception is thrown and #underline[no supervision strategy is defined.]
]

== Supervision essentials
#feature-block(
  [What it is],
  [
    Supervision lets a parent #bold[declaratively define] what to do when child actors fail with specific exceptions.
  ],
)

#feature-block(
  [Where to apply],
  [
    Wrap child behavior with `Behaviors.supervise(...)`, usually where the parent spawns the child.
  ],
)

== Common supervision strategies
```scala
Behaviors.supervise(behavior)
  .onFailure[IllegalStateException](SupervisorStrategy.restart)
Behaviors.supervise(behavior)
  .onFailure[IllegalStateException](SupervisorStrategy.resume)
Behaviors.supervise(behavior)
  .onFailure[IllegalStateException](
    SupervisorStrategy.restart.withLimit(
      maxNrOfRetries = 10,
      withinTimeRange = 10.seconds,
    )
  )
Behaviors.supervise(behavior)
  .onFailure[IllegalStateException](SupervisorStrategy.restart)
  .onFailure[IllegalArgumentException](SupervisorStrategy.stop)
```

== Restart semantics and wrapping
#warning-block(
  [Important note],
  [
    On restart, Pekko re-installs the #bold[original behavior] passed to `Behaviors.supervise`.
    If mutable state is involved, create actors through `Behaviors.setup`.
  ],
)
#v(0.5em)
```scala
def apply(): Behavior[Command] =
  Behaviors.supervise(counter(1)).onFailure(SupervisorStrategy.restart)
```
#note-block(
  [Wrapping behavior],
  [
    In functional style, applying supervision at the top-level is enough: returned behaviors are re-wrapped automatically.
  ],
)

== Escalating failures

Given the parent-child hierarchy, if a child fails, the parent can *get notified*.

#codly(
  header: [`basics / io.github.nicolasfara.es00.basics.ParentFailureNotification.scala`],
  header-cell-args: (align: center, ),
)
```scala
object ParentActor:
  def apply(): Behavior[String] = Behaviors.setup: ctx =>
    ctx.watch(ctx.spawn(ChildFailingActor(), "child-actor"))
    Behaviors.receiveSignal:
      case (_, Terminated(ref)) =>
        ctx.log.info(s"Child $ref has terminated")
        Behaviors.stopped

object ChildFailingActor:
  def apply(): Behavior[String] = Behaviors.setup: _ =>
    throw new RuntimeException("I failed")
```

= Basic Techniques

== Fire and forget

#feature-block("Fire and forget")[
  Pekko's core API is designed for *fire-and-forget* message sending, which is the most common interaction pattern.
  You can send messages to an actor without expecting a reply, and the actor will process them #bold[asynchronously].
]

- Pekko delivery guarantee: *at-most-once* delivery, which means that messages may be lost but will not be duplicated.
- Pekko ordering guarantee: message ordering is guaranteed *per sender-receiver* pair, but not across the whole system.

== Request-response
#feature-block("Request-response")[
  For interactions that require a reply, the common pattern is to include an `ActorRef` in the message for the reply to be sent to.

  ```scala
  enum Protocol:
    case Request(data: String, replyTo: ActorRef[Response])
    case Response(result: String)
  ```

  This way, the sender can provide a reference for where the response should be sent, and the receiver can reply directly to that reference.
]

== Request-response with ask

#slide(title: [Request-response with ask], composer: (1.2fr, 1fr))[
  #codly(
    header: [`basics / io.github.nicolasfara.es00.basics.AskOperator.scala`],
    header-cell-args: (align: center, ),
  )
  ```scala
  given Timeout = 3.seconds

  val greeting: Future[GreeterActor.Greeting] = target ? { replyTo =>
    GreeterActor.Command.Greet("Pekko", replyTo)
  }
  ```

  #feature-block(
    [When `ask` is useful],
    [
      - Bridge actor messages to `Future`-based APIs.
      - Request one reply with a clear timeout boundary.
      - Keep protocol explicit: the request still carries a typed `replyTo`.
    ],
  )

  // #warning-block(
  //   [Use sparingly],
  //   [
  //     `ask` creates extra machinery (temporary actor + timeout handling).
  //     Prefer direct message-driven protocols for internal actor-to-actor collaboration.
  //   ],
  // )
]

#slide(title: [Timers and per-session actors], composer: (1fr, 1fr))[
  ```scala
  Behaviors.withTimers[Command] { timers =>
    timers.startSingleTimer(Remind, 300.millis)
    Behaviors.receiveMessage {
      case Remind => Behaviors.same
      case Stop => Behaviors.stopped
    }
  }
  ```

  #feature-block(
    [Per-session child actor],
    [
      For a complex request, spawn a short-lived child that gathers replies, enforces a timeout, and sends one final answer.
    ],
  )
]

#slide(title: [Stash and FSM modeling])[
  #components.side-by-side(columns: (1fr, 1fr), gutter: 12pt)[
    #feature-block([Stash], [
      Buffer messages that cannot yet be processed, for example while loading initial state or waiting for an external result.
    ])
  ][
    #feature-block([Finite-state logic], [
      Model each state as a behavior. The behavior returned after one message encodes the next state.
    ])
  ]
  #v(0.5em)
  ```scala
  Behaviors.withStash(100) { buffer =>
    Behaviors.setup[Command] { ctx =>
      loading(ctx, buffer)
    }
  }
  ```
]

#slide(title: [Blocking, dispatchers, and discovery])[
  #warning-block(
    [Do not block the default dispatcher],
    [
      Blocking inside a message handler starves unrelated actors that share the same threads.
      Wrapping blocking code in a future is not enough if that future still uses the actor dispatcher.
    ],
  )
  #v(0.4em)
  ```scala
  val blockingEc =
    context.system.dispatchers.lookup(
      DispatcherSelector.fromConfig("my-blocking-dispatcher")
    )
  ```
  #v(0.4em)
  `Receptionist` discovery is the standard way to register a `ServiceKey` and look up peers dynamically.
]

= Testing

#slide(title: [Testing strategy])[
  #components.side-by-side(columns: (1fr, 1fr), gutter: 12pt)[
    #feature-block([`BehaviorTestKit`], [
      - Synchronous
      - Great for pure behavior logic
      - Inspect effects such as spawn, watch, and logs
      - Fast and deterministic
    ])
  ][
    #feature-block([`ActorTestKit`], [
      - Runs real actors in a real actor system
      - Better for interactions, timing, and protocol wiring
      - Uses probes as queryable mailboxes
    ])
  ]
  #v(0.5em)
  Start with `BehaviorTestKit`; switch to `ActorTestKit` when collaboration is the real subject of the test.
]

#slide(title: [Synchronous test example])[
  ```scala
  import org.apache.pekko.actor.testkit.typed.scaladsl.{BehaviorTestKit, TestInbox}

  val testKit = BehaviorTestKit(Counter(0))
  val inbox = TestInbox[Int]()

  testKit.run(Counter.Command.Tick)
  testKit.run(Counter.Command.Get(inbox.ref))

  inbox.expectMessage(1)
  ```

  #feature-block(
    [What this buys you],
    [
      - No scheduler races
      - Easy inspection of outgoing messages
      - Good coverage for protocol and state transition logic
    ],
  )
]

#slide(title: [Asynchronous test example])[
  ```scala
  import org.apache.pekko.actor.testkit.typed.scaladsl.ActorTestKit
  import org.scalatest.wordspec.AnyWordSpecLike

  class CounterSpec extends AnyWordSpecLike:
    val testKit = ActorTestKit()

    "Counter" should {
      "reply with the current value" in {
        val counter = testKit.spawn(Counter(2))
        val probe = testKit.createTestProbe[Int]()
        counter ! Counter.Command.Get(probe.ref)
        probe.expectMessage(2)
      }
    }
  ```
  A test probe is a mailbox you can assert against, which makes it ideal for reply-oriented protocols.
]

= Wrap-up

#slide(title: [Common mistakes to avoid])[
  #warning-block(
    [Frequent pitfalls],
    [
      - Blocking directly in handlers
      - Using ask everywhere instead of message-driven protocols
      - Treating supervision as input validation
      - Exposing internal implementation details in the public protocol
      - Building giant actors instead of small collaborators with clear ownership
    ],
  )
]

#slide(title: [What we learned and what comes next])[
  #feature-block(
    [Key takeaways],
    [
      - Actors provide isolation, explicit protocols, and structured failure handling.
      - Pekko Typed makes message contracts first-class through types.
      - Lifecycle, supervision, timers, stash, and testing are the practical core.
      - The same foundations extend to remoting, clustering, persistence, and streams.
    ],
  )
  #v(0.5em)
  #note-block(
    [Suggested follow-up topics],
    [
      Next lectures can build on this deck with cluster membership, sharding, persistence, and stream integration.
    ],
  )
]

#slide(title: [Acknowledgement and references])[
  #feature-block(
    [Acknowledgement],
    [
      The original seminar structure and part of the teaching material derive from
      earlier Akka-oriented slides used in the course and from Roberto Casadei's material.
    ],
  )
  #v(0.4em)
  #feature-block(
    [Primary references],
    [
      - Apache Pekko documentation: #link("https://pekko.apache.org/docs/pekko/current/")[pekko.apache.org/docs/pekko/current/]
      - Apache Pekko modules overview: #link("https://pekko.apache.org/modules.html")[pekko.apache.org/modules.html]
      - Typed actor discovery and dependency snippets: #link("https://pekko.apache.org/docs/pekko/current/typed/actor-discovery.html")[typed/actor-discovery]
      - Typed testing guide: #link("https://pekko.apache.org/docs/pekko/current/typed/testing.html")[typed/testing]
    ],
  )
]
