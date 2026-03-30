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
        fill: rgb("#c46a11"),
        weight: "medium",
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
  The actor model provides a level of abstraction that makes it easier to write correct concurrent and distributed software.

=== Asynchronous messages
  Actors communicate through asynchronous messages, which decouples the sender and receiver and allows for more flexible and scalable designs.


=== Explicit protocols
  The actor model encourages the use of explicit protocols, which can improve the clarity and maintainability of the code.

// #slide(title: [Why actors?])[
//   #feature-block(
//     [Motivation],
//     [
//       - Shared-state concurrency couples correctness to locks and thread scheduling.
//       - Actors isolate state and communicate only through asynchronous messages.
//       - This maps well to services, pipelines, supervisors, and distributed workflows.
//       - The model encourages explicit protocols instead of hidden method calls.
//     ],
//   )

//   #placeholder-figure(
//     [Actor hierarchy sketch],
//     caption: [Use a future diagram to contrast isolated mailboxes with shared-state objects.],
//   )
// ]

#slide(title: [What is Apache Pekko?])[
  #feature-block(
    [Toolkit overview],
    [
      Apache Pekko is an open-source toolkit for building concurrent, distributed,
      and resilient message-driven applications on the JVM.

      It carries forward the actor-based programming model, offers typed and classic APIs,
      and integrates modules for clustering, streams, persistence, and testing.
    ],
  )

  #note-block(
    [Historical note],
    [
      Many older slides, blog posts, and repositories still say _Akka_.
      When migrating code, the main change is usually from `akka.*` / `com.typesafe.akka`
      to `org.apache.pekko` / `pekko.*`, plus updated dependency coordinates.
    ],
  )
]

#slide(title: [Core modules and ecosystem])[
  #feature-block(
    [Frequently used modules],
    [
      - `pekko-actor-typed`: typed actors and actor systems
      - `pekko-actor-testkit-typed`: synchronous and asynchronous testing
      - `pekko-stream`: Reactive Streams implementation
      - `pekko-cluster-typed`, `pekko-persistence-typed`, and discovery/management modules
      - Start local first; distributed features make sense once protocols and supervision are clear
    ],
  )
]

= Actor Foundations

#slide(title: [The actor mental model])[
  #feature-block(
    [Each actor encapsulates three things],
    [
      1. State, hidden behind the actor reference
      2. Behavior, chosen message by message
      3. A mailbox, where incoming messages wait before processing
    ],
  )
  #v(0.5em)
  #components.side-by-side(columns: (1fr, 1fr), gutter: 8pt)[
    #feature-block([On receive], [
      - Send messages
      - Spawn children
      - Return the next behavior
    ])
  ][
    #feature-block([Useful metaphors], [
      - Workers and supervisors
      - Delegation trees
      - Failure ownership
    ])
  ]
  #v(0.5em)
  #note-block(
    [Boundary],
    [
      Actors are not threads and not shared-memory objects.
    ],
  )
]

#slide(title: [Actor systems, refs, and paths], composer: (1.2fr, 1fr))[
  #feature-block(
    [System structure],
    [
      - An `ActorSystem[T]` is the heavyweight runtime container.
      - A system manages dispatchers, scheduling, addresses, and top-level guardians.
      - Recommendation: one actor system per logical application boundary.
      - Child actors form a supervision hierarchy under `/user`.
    ],
  )
  #note-block(
    [Reference vs path],
    [
      - `ActorRef[T]`: capability to send messages to a live actor
      - Actor path: a name in the hierarchy, whether currently inhabited or not
      - Ordering is guaranteed per sender/receiver pair, not globally
    ],
  )

  #placeholder-figure(
    [System /user /system layout],
    caption: [Replace with a hierarchy diagram if you later add custom visuals.],
    height: 5.2cm,
  )
]

#slide(title: [Mailboxes, isolation, and throughput])[
  #feature-block(
    [Operational intuition],
    [
      - Actors are logical concurrency units; dispatchers decide which threads run them.
      - Lightweight actors scale because most actors are inactive most of the time.
      - Message passing removes lock sharing, but protocol design still matters.
      - At-most-once delivery means failures and retries belong in the protocol or infrastructure.
    ],
  )
  #v(0.5em)
  #warning-block(
    [Important boundary],
    [
      Actor isolation does not magically remove back-pressure, overload, or failure handling.
      It gives you a disciplined place to model them.
    ],
  )
]

= Typed API

#slide(title: [Getting started with Pekko Typed])[
  ```scala
  scalaVersion := "3.3.3"

  val pekkoVersion = "1.4.0"

  libraryDependencies ++= Seq(
    "org.apache.pekko" %% "pekko-actor-typed" % pekkoVersion,
    "org.apache.pekko" %% "pekko-actor-testkit-typed" % pekkoVersion % Test,
    "ch.qos.logback" % "logback-classic" % "1.5.18",
    "org.scalatest" %% "scalatest" % "3.2.19" % Test
  )
  ```
  `org.apache.pekko` and `pekko-actor-typed` are the main migration targets from older Akka snippets.
]

#slide(title: [Core typed abstractions])[
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
]

#slide(title: [Running example: protocol first], composer: (1fr, 1fr))[
  ```scala
  object Counter:
    enum Command:
      case Tick
      case Get(replyTo: ActorRef[Int])
  ```

  #feature-block(
    [Why start from the protocol?],
    [
      - The protocol is the public API of the actor.
      - Typed references make invalid messages unrepresentable.
      - Reply channels are explicit through `replyTo`.
      - Tests and collaborations are easier to reason about.
    ],
  )
]

#slide(title: [Functional style])[
  ```scala
  object Counter:
    enum Command:
      case Tick
      case Get(replyTo: ActorRef[Int])

    def apply(current: Int): Behavior[Command] =
      Behaviors.receive { (context, msg) =>
        msg match
          case Command.Tick => Counter(current + 1)
          case Command.Get(replyTo) =>
            replyTo ! current
            Behaviors.same
      }
  ```
]

#slide(title: [Object-oriented style and tradeoffs])[
  ```scala
  object CounterObject:
    def apply(): Behavior[Counter.Command] =
      Behaviors.setup(ctx => new CounterObject(ctx, 0))

  final class CounterObject(
      context: ActorContext[Counter.Command],
      var current: Int,
  ) extends AbstractBehavior[Counter.Command](context):
    override def onMessage(msg: Counter.Command): Behavior[Counter.Command] = msg match
      case Counter.Command.Tick => current += 1; this
      case Counter.Command.Get(replyTo) => replyTo ! current; this
  ```
  Functional style fits immutable state and FSMs; OOP style is fine when local mutable state improves readability.
]

#slide(title: [Lifecycle and supervision])[
  #feature-block(
    [Lifecycle],
    [
      - Root actor: `ActorSystem(behavior, "name")`
      - Child creation: `context.spawn`
      - Stop self: `Behaviors.stopped`
      - Stop child: `context.stop(childRef)`
      - Watch children: `context.watch`
    ],
  )
  #v(0.5em)
  #feature-block(
    [Supervision],
    [
      - Typed actors stop by default on failure
      - Wrap child behavior with `Behaviors.supervise(...)`
      - Typical strategies: `restart`, `resume`, `restartWithBackoff`
      - If you watch, handle `Terminated`
    ],
  )
]

= Basic Techniques

#slide(title: [Interaction patterns])[
  #feature-block(
    [Patterns you will use constantly],
    [
      - Fire-and-forget: `ref ! msg`
      - Request-response: include `replyTo: ActorRef[Res]` in the command
      - Ask pattern: bridge request-response to a future when integrating with non-actor code
      - `pipeToSelf`: translate async completion back into an internal message
    ],
  )
  #v(0.5em)
  ```scala
  case class Fetch(id: String, replyTo: ActorRef[Result]) extends Command

  context.ask(worker, Worker.Fetch(id, _)) {
    case Success(value) => WrappedResult(value)
    case Failure(err) => WorkerFailed(err)
  }
  ```
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
