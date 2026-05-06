#import "@preview/touying:0.6.3": *
#import themes.metropolis: *
#import "@preview/ctheorems:1.1.3": *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "utils.typ": *

#let small-code(body) = {
  show raw: set text(size: 0.82em, font: "JetBrains Mono")
  body
}

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
    title: [Apache Pekko for Distributed Systems],
    subtitle: [Pekko Artery Remoting and Pekko Cluster: Introduction],
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
      show link: set text(
        font: "JetBrains Mono",
        fill: rgb("#eb811b"),
      )

      show bibliography: set text(size: 0.75em)
      show footnote.entry: set text(size: 0.75em)
      set strong(delta: 200)
      set par(justify: true)
      body
    }
  )
)
#title-slide()

#slide(title: [Agenda])[
  #feature-block(
    [Today's Topics],
    [
      - *Cluster Concepts*: Membership, gossip convergence, and failure detection
      - *Pekko Remote Artery*: Location transparency, configuration, and serialization
      - *Pekko Clustering*: Cluster membership, gossiping, and failure detection
      - *Advanced Facilities*: Receptionist, Group Router, Distributed Data, and Sharding
    ],
  )
]


= Cluster Concepts

== Distributed Membership

#feature-block("What Pekko Cluster models")[
  Pekko Cluster lets one application span several actor systems, each running as a logical #bold[node].
  A node is identified by `hostname:port:uid`, so several nodes may even run on the same physical machine.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Decentralized")[
    Membership is peer-to-peer: no permanent master, no central registry, and no single bottleneck for cluster state.
  ]
][
  #note-block("What is tracked")[
    The cluster tracks members, their lifecycle state, and whether each member is currently `reachable` or `unreachable`.
  ]
]

== Gossip and Convergence

#feature-block("How nodes agree")[
  Cluster state is disseminated by *gossip*#footnote("https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf"): nodes periodically exchange their view of membership with other nodes, preferring peers that have not seen the latest state.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Vector clocks")[
    Each state update carries version information, allowing nodes to detect older, newer, or conflicting membership views and #underline[merge them].
  ]
][
  #note-block("Seen set")[
    A state is *converged* when #bold[every reachable node has observed the current version].
    Until convergence, membership transitions wait.
  ]
]

== Failure Detection

#feature-block("Failure is suspicion, not certainty")[
  Pekko uses a #link("https://pekko.apache.org/docs/pekko/current/typed/failure-detector.html", "Phi Accrual Failure Detector"): heartbeat timing is interpreted as a suspicion level, which can be tuned for the deployment environment.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Spread by gossip")[
    When one monitor marks a node `unreachable`, that information is propagated through the cluster.
    The node may later become `reachable` again.
  ]
][
  #warning-block("Operational consequence")[
    Gossip convergence cannot complete while members are unreachable.
    They must recover, or be downed and removed, before the leader can advance membership.
  ]
]

== Leader and Joining

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Leader")[
    The leader is a deterministic role recognized after convergence, not a long-running elected process.
    It promotes `joining` nodes to `up` and completes removals.
  ]
][
  #feature-block("Seed nodes")[
    Seed nodes are only contact points for new members.
    Once the cluster is running, membership does not depend on seed nodes as special coordinators.
  ]
]

#note-block("Why this comes before Artery")[
  Cluster gives the distributed actor system its membership semantics.
  Artery is the remoting transport that lets those actor systems communicate.
]

= Pekko Remote Artery

== Artery Overview

#feature-block("What Artery is")[
  *Artery* is the remoting subsystem by which actor systems on different nodes #bold[talk to each other].
  It replaced classic remoting and keeps the actor API *location-transparent*.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Recommended usage")[
    In practice, prefer Pekko Cluster, or higher-level protocols such as HTTP and gRPC, instead of using remoting directly.
  ]
][
  #note-block("Peer-to-peer")[
    Remoting is not server-client: any remoting-enabled system can connect to any other one if it knows the target `ActorRef`.
  ]
]

// #note-block("ByteBuffer-based serializers")[
//   Artery also supports `ByteBufferSerializer`, which can reduce allocations and improve throughput for high-volume messaging.
// ]
== Selecting a Transport

#feature-block("Three transport choices")[
  - `tcp`: default and simplest choice
  - `tls-tcp`: TCP with encryption
  - `aeron-udp`: high throughput and low latency, but more operationally demanding
]

#note-block("Practical guidance")[
  Use `tcp` unless you need TLS or Aeron-specific performance. Switching the transport protocol later is not a rolling update.
]

== Configuration

We can configure Artery Remoting in `application.conf`:

#small-code[
#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko.actor.provider = cluster
pekko.remote.artery {
  transport = tcp
  canonical.hostname = "127.0.0.1"
  canonical.port = 25520
}
```
]

#note-block("Canonical address")[
  The canonical host and port are the globally reachable address that other systems use to connect back.
  In NAT, Docker, or Kubernetes setups, separate the external canonical address from the local bind address. See the #link("https://pekko.apache.org/docs/pekko/1.3/remoting-artery.html#remote-configuration-nat-artery", "documentation") for details.
]

// == Acquiring references to remote actors

// In order to communicate with an actor, it is necessary to have its ```scala ActorRef```.
// Locally, this is usually obtained by the actor creator (`actorOf()` caller), then shared with others.

// #feature-block("How to get a remote ActorRef")[
//   - Receive it in a message (`sender()` or payload, e.g. `PleaseReply(..., remoteActorRef: ActorRef)`).
//   - Or look up a known path with `ActorSelection`.
// ]

// #feature-block("Remoting-enabled methods")[
//   - *Remote lookup:* `actorSelection(path)`
//   - *Remote creation:* `actorOf(Props(...), actorName)`
// ]

// #note-block("Legacy Note")[
//   In Pekko/Akka Classic, this was supported through `actorSelection` (retrieving an `ActorRef` from a URL like `pekko://sys@host:port/user/actor`). In Typed, the `Receptionist` is the preferred mechanism.
// ]

== Joining a cluster programmatically

To #bold[join] a cluster programmatically, send a `Join` message to the Cluster Manager:
#codly(
  header: [`cluster / io.github.nicolasfara.es01.cluster.joining.ManualJoin.scala`],
  header-cell-args: (align: center, ),
)
```scala
val clusterSystem1 = Cluster(system1)
clusterSystem1.manager ! Join(clusterSystem1.selfMember.address)
// Other config
val clusterSystem2 = Cluster(system2)
clusterSystem2.manager ! Join(clusterSystem1.selfMember.address)
```

To #bold[leave] the cluster, send a `Leave` message:
```scala
clusterSystem1.manager ! Leave(clusterSystem1.selfMember.address)
```

== Acquiring references to remote actors

To communicate with (remote) actors, you need their `ActorRef`. You can get it by:

#components.side-by-side[
  #feature-block("In a message")[
    Include the `ActorRef` in the message payload, e.g. `Reply(..., ref: ActorRef[T])`.
    But the first message?
  ]
][
  #feature-block("Via actor selection")[
    Use `actorSelection(path)` to look up an actor by its path. This is not location-transparent and should be used with care.
  ]
]

#warning-block("Be careful")[
 Both methods require you to know the remote actor's path or have it sent to you, which can break location transparency and tightens coupling between actors.
]

== Receptionist and Service Keys

When an actor needs to be discovered by another actor, the recommended approach is to use the *Receptionist* and *Service Keys*:

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("How discovery works")[
    - Register a service actor under a typed `ServiceKey[T]`
    - Other actors query the receptionist through messages, not direct lookups
    - A `Listing` reply contains the current `Set[ActorRef[T]]` for that key
  ]
][
  #note-block("Dynamic registry")[
    - `Receptionist.Register(key, ref)` makes an actor discoverable
    - `Receptionist.Find(...)` gives a point-in-time snapshot
    - `Receptionist.Subscribe(...)` pushes the first listing and later changes
  ]
]

#pagebreak()

#small-code[
```scala
val PingServiceKey = ServiceKey[Ping]("pingService")

context.system.receptionist ! Receptionist.Register(PingServiceKey, context.self)
context.system.receptionist ! Receptionist.Find(PingServiceKey, listingAdapter)
context.system.receptionist ! Receptionist.Subscribe(PingServiceKey, context.self)
```
]

#note-block("Lifecycle")[
  Several actors may share the same key. Entries disappear when an actor stops, is deregistered, or its node is removed from the cluster.
]

== Cluster Receptionist

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Cluster semantics")[
    - Registrations on one node #bold[appear in the receptionist of the other cluster] nodes
    - State is propagated via distributed data
    - Convergence is eventual: nodes reach the same service set per `ServiceKey`
  ]
][
  #note-block("Reachability-aware listings")[
    - `Find` and `Subscribe` only return #bold[reachable] service instances
    - Unreachable ones are excluded
    - The full set can still be inspected through `Listing.allServiceInstances`
  ]
]

#warning-block("Important constraints")[
  Cluster receptionist is #bold[great for initial contact] and loose discovery, but all cross-node messages must be serializable and the receptionist *is not meant* for unlimited scale or very high service churn.
]

== Routers

#feature-block("Why routers exist")[
  A router is #bold[itself an actor]: you send one message to the router, and it forwards that message to one routee chosen from a set of actors able to handle the same protocol.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Pool router")[
    - Created from a `Behavior[T]`
    - Spawns a fixed number of local child
    - Best when you want parallel workers inside one actor system
  ]
][
  #feature-block("Group router")[
    - Created from a `ServiceKey[T]`
    - Uses the receptionist to discover routees
    - Can route to actors on other reachable cluster nodes
  ]
]

#pagebreak()

#note-block("Distributed takeaway")[
  For clustered applications, the interesting one is the #bold[group router]: it composes naturally with receptionist-based discovery and keeps senders decoupled from concrete actor locations.
]

== Pool Router

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Semantics")[
    - `Routers.pool(n)(behavior)` creates `n` routee children
    - Routees are #bold[always local]: a pool does not distribute work across the cluster
    - If a child stops, the router removes it from the pool
  ]
][
  #note-block("Operational notes")[
    - Supervise the worker behavior if failures should restart it
    - The default strategy is #bold[round robin]
    - A pool can also recognize special messages that should be #bold[broadcast] to all routees
  ]
]

#small-code[
```scala
val pool = Routers.pool(poolSize = 4) {
  Behaviors.supervise(Worker()).onFailure[Exception](SupervisorStrategy.restart)
}
val router = ctx.spawn(pool, "worker-pool")
router ! Worker.DoLog("msg")
```
]

== Group Router

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("How it works")[
    - Register workers under a `ServiceKey[T]`
    - Build the router with `Routers.group(serviceKey)`
    - The router subscribes to receptionist listings and forwards messages to discovered routees
  ]
][
  #note-block("Cluster behavior")[
    - Reachable routees on #bold[any cluster node] may be selected
    - Membership is #bold[eventually consistent] because discovery relies on receptionist
    - On startup, the router stashes messages until it receives its first listing
  ]
]

#small-code[
```scala
val serviceKey = ServiceKey[Worker.Command]("log-worker")
ctx.system.receptionist ! Receptionist.Register(serviceKey, worker)

val group = Routers.group(serviceKey)
val router = ctx.spawn(group, "worker-group")
router ! Worker.DoLog("msg")
```
]

#pagebreak()

#warning-block("Important edge case")[
  After the first receptionist listing, if the discovered set is empty, the group router drops incoming messages. That makes it great for elastic discovery, but not a substitute for guaranteed delivery or back-pressure.
]

== Routing strategies and limits

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Built-in strategies")[
    - *Round robin:* fair rotation across routees; default for pool routers
    - *Random:* good when membership changes often; default for group routers
    - *Consistent hashing:* same key tends to hit the same routee while membership stays stable
  ]
][
  #warning-block("Performance reality")[
    - More routees help only if the workload and dispatcher can actually exploit parallelism
    - For CPU-bound workers, extra routees beyond available threads seldom help
    - The router head processes incoming messages sequentially, so it can become a bottleneck at very high throughput
  ]
]

#pagebreak()

#note-block("When to use what")[
  Use a #bold[pool router] for local worker parallelism, a #bold[group router] for cluster-aware service discovery, and consider #link("https://pekko.apache.org/docs/pekko/current/typed/cluster-sharding.html", "Cluster Sharding") when you need stable key-based routing with rebalancing.
]


== Serialization

#feature-block("Why serialization matters")[
  Messages between actors in the same JVM are passed by reference, but once a message leaves the JVM it must be turned into bytes and reconstructed on the other side.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Recommended choices")[
    - #bold[Jackson] is the recommended default for application messages
    - #bold[Protocol Buffers] are a good fit when you want tighter schema control
    // - Pekko itself uses Protobuf for several internal messages
  ]
][
  #note-block("Core idea")[
    Pekko separates:
    - the #bold[serializer implementation]
    - the #bold[binding] from message type to serializer
  ]
]

== Serialization configuration

#small-code[
#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko.actor.serializers {
  jackson-cbor = "org.apache.pekko.serialization.jackson.JacksonCborSerializer"
  proto = "org.apache.pekko.remote.serialization.ProtobufSerializer"
}

pekko.actor.serialization-bindings {
  "it.unibo.pcd.pekko.CborSerializable" = jackson-cbor
  "com.google.protobuf.Message" = proto
}
```

```scala
libraryDependencies += "org.apache.pekko" %% "pekko-serialization-jackson" % PekkoVersion
```
]

#pagebreak()

#note-block("Binding rule")[
  Bind a trait, interface, or abstract base class rather than each concrete message class. If more than one binding matches, Pekko uses the most specific one and warns about ambiguous cases.
]

// == Custom serializers and evolution

// #components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
//   #feature-block("Custom serializer guidance")[
//     - Implement a custom `Serializer` or `SerializerWithStringManifest`
//     - Prefer `SerializerWithStringManifest` for formats that must evolve over time
//     - The serializer `identifier` must remain unique and stable
//   ]
// ][
//   #note-block("Why string manifests help")[
//     - The manifest can encode logical type names or versions
//     - Old bytes can still be read after classes move or are renamed
//     - This is especially useful for persistence and rolling updates
//   ]
// ]

// #small-code[
// ```scala
// val bytes = serialization.serialize(msg).get
// val serializerId = serialization.findSerializerFor(msg).identifier
// val manifest = Serializers.manifestFor(serialization.findSerializerFor(msg), msg)
// ```
// ]

// #warning-block("Rolling-update rule")[
//   A serialized message is effectively `(serializer-id, manifest, bytes)`. To migrate to a new serializer safely, first roll out the new serializer class everywhere, and only in a second rolling update bind message types to it.
// ]

// == Actor refs, testing, and Java serialization

// #components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
//   #feature-block("ActorRef inside messages")[
//     - `ActorRef`s are commonly part of the protocol
//     - With Jackson they are handled for you
//     - In custom serializers, use `ActorRefResolver` to turn refs into strings and back
//   ]
// ][
//   #note-block("Verification in tests")[
//     - `pekko.actor.serialize-messages = on` forces serialization even for local messages
//     - Useful to catch non-serializable protocols early
//     - Keep it for tests, not production
//   ]
// ]

// #warning-block("Java serialization")[
//   Java serialization is disabled by default, discouraged in production, and should be treated as a security risk as well as a performance bottleneck. If it ever appears in logs, that deserves attention.
// ]

== Remote Security

#feature-block("Protect remoting")[
  - Prefer `tls-tcp` when messages must be encrypted
  - Use mutual authentication between peers
  - Do not expose Artery directly on an untrusted network
]

#warning-block("Untrusted mode")[
  `pekko.remote.artery.untrusted-mode = on` blocks remote deployment, remote DeathWatch, system-stop style messages, and messages marked `PossiblyHarmful`.
]

// #note-block("Trusted selection paths")[
//   If you need limited actor-selection access, allow only specific paths with `pekko.remote.artery.trusted-selection-paths`.
// ]

== Delivery guarantees, remote watch, and quarantine

Pekko guarantees: (1) #bold[at-most-once delivery]; and (2) #bold[message ordering] between pairs of actors.
Artery uses TCP or Aeron as a "reliable" underlying message transport.

#warning-block("Cases when messages may not be delivered")[
  - During a network partition (TCP connection / Aeron session broken)
  - When sending too many messages without flow control (filling outbound queue)
  - On de/serialization failure
  - Exception in the remoting infrastructure
]

#pagebreak()

#feature-block("Remote Watch and Quarantine")[
  - *Remote watch:* You can watch remote actors just like local actors. A failure detector uses heartbeats to generate `Terminated`.
  - System messages for death watch are delivered with "exactly once" guarantee.
  - If a system message cannot be delivered, the destination enters the *quarantined* state.
  - The only way to recover from quarantine is to restart the actor system.
]

= Pekko Clustering

== Cluster Overview

#feature-block("What Pekko Cluster gives you")[
  Pekko Cluster is a decentralized, peer-to-peer membership service for actor systems spread across multiple nodes.
  There is no single coordinator or single bottleneck: cluster state is disseminated with gossip and monitored by a failure detector.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Why it matters")[
    Build one application or service across many nodes while keeping the actor model and location transparency.
  ]
][
  #note-block("Main ingredients")[
    Membership state, gossip dissemination, automatic failure detection, and deterministic leadership for convergence.
  ]
]

== Cluster Vocabulary

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Node")[
    A logical cluster member identified by a `hostname:port:uid` tuple. Multiple nodes can live on the same machine.
  ]

  #feature-block("Cluster")[
    The set of nodes joined together through the Cluster Membership Service.
  ]
][
  #feature-block("Leader")[
    A role, not a permanently elected machine. When gossip has converged, the leader manages membership transitions.
  ]

  #feature-block("Reachability")[
    `reachable` and `unreachable` are cluster states inferred by the failure detector and propagated by gossip.
  ]
]

== Gossip, Convergence, and Failure Detection

#feature-block("How membership state is shared")[
  Cluster state is spread with a gossip protocol. Each state update carries a vector clock, which helps reconcile and merge concurrent changes.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Convergence")[
    Gossip converges when every node is in the seen set for the current state version.
    Convergence cannot be reached while some node is `unreachable`.
  ]
][
  #note-block("Failure detector")[
    A Phi Accrual Failure Detector monitors nodes by heartbeat and marks them `unreachable` or `reachable` again.
  ]
]

#warning-block("Partition handling")[
  If a system message cannot be delivered, the destination can be quarantined.
  In practice the cluster must down or remove the node, and the quarantined actor system must be restarted before joining again.
]

== Leader and Seed Nodes

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Leader responsibilities")[
    - Promote `joining` members to `up`
    - Move `exiting` members to `removed`
    - Act only after gossip convergence
  ]
][
  #feature-block("Seed nodes")[
    - Contact points for new nodes joining the cluster
    - Useful for bootstrapping, but not required for steady-state operation
    - A new member can join through any current member, not just a seed node
  ]
]

== Pekko Cluster: basic usage (1/2)

```scala
libraryDependencies ++= Seq(
  "org.apache.pekko" %% "pekko-cluster-typed" % PekkoVersion,
  "org.apache.pekko" %% "pekko-serialization-jackson" % PekkoVersion
)
```

The Cluster extension gives you access to management tasks such as Joining, Leaving and Downing and subscription of cluster membership events such as `MemberUp`, `MemberRemoved`, and `UnreachableMember`.

```scala
// Access the Cluster extension on a node
val cluster = Cluster(system)
```

#note-block("Key references on the Cluster extension")[
  - `manager`: an `ActorRef[ClusterCommand]` (e.g., `Join`, `Leave`, `Down`)
  - `subscriptions`: an `ActorRef[ClusterStateSubscription]`
  - `state`: the current `CurrentClusterState`
]

== Pekko Cluster: basic usage (2/2)

#small-code[
#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko.actor.provider = "cluster"
pekko.remote.artery.canonical.hostname = "127.0.0.1"
pekko.remote.artery.canonical.port = 2551
pekko.cluster.seed-nodes = [
  "pekko://ClusterSystem@127.0.0.1:2551",
  "pekko://ClusterSystem@127.0.0.1:2552"
]
```
]

== Cluster Membership: Joining

Joining through #bold[seed nodes] (point of contact for new nodes that join the cluster):

1. *Join configured seed nodes:* \
   `pekko.cluster.seed-nodes=["pekko://Sys@host1:2551", ...]` \
   The first seed must be started first to allow other seeds to join!

2. *Join seed nodes programmatically:*
   ```scala
   val seedNodes: List[Address] = // discover in some way
   Cluster(system).manager ! JoinSeedNodes(seedNodes)
   ```

3. *Join automatically:* via Cluster Bootstrap (usually with Kubernetes or similar).

#note-block("Joining a cluster programmatically")[
  Without using seed nodes: `cluster.manager ! Join(cluster.selfMember.address)`
]

== Cluster Membership: Leaving & Subscriptions

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Leaving a cluster")[
    - *Programmatically:*
      `cluster.manager ! Leave(address)`
    - *Graceful exit:* via Coordinated Shutdown (e.g. `sys.terminate()`)
    - *Non-graceful exit:* E.g. in case of abrupt termination, the node will be detected as unreachable by other nodes and removed after Downing.
  ]
][
  #feature-block("Subscriptions")[
    Receive cluster state changes, e.g. to be notified of a node leaving the cluster:

    ```scala
    val subscriber: ActorRef[MemberEvent] = ...
    cluster.subscriptions ! Subscribe(
      subscriber,
      classOf[MemberEvent]
    )
    ```
  ]
]

== Node roles

#feature-block("Motivation")[
  Not all nodes of a cluster need to perform the same function.
  Choosing which actors to start on each node can take roles into account to properly distribute responsibilities.
]

*Configuration:*
Config key `pekko.cluster.roles`

*Getting role info:*
Role info is included in membership information (cf. `MemberEvent`).
For the own node, `cluster.selfMember.hasRole(r)`.

```scala
val selfMember = Cluster(context.system).selfMember
if (selfMember.hasRole("backend")) {
  context.spawn(Backend(), "back")
} else { /* spawn frontend or other roles */ }
```

== Pekko Cluster facilities

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #feature-block("Receptionist & Group router")[
    - *Receptionist:* Service registrations are replicated cluster-wide via distributed data; lookups return reachable instances for a `ServiceKey`.
    - *Group router:* Created for a `ServiceKey`, uses receptionist to discover actors, and routes messages. Cluster-aware out-of-the-box.
  ]

  #feature-block("Distributed data")[
    A cluster-wide key-value store where values are CRDTs. Local updates + replication via gossip + conflict-resolution.
  ]
][
  #feature-block("Cluster singleton")[
    Support for managing one singleton actor in the entire cluster.
  ]

  #feature-block("Cluster sharding")[
    Distribute and interact with actors based on their logical ID. A `ShardRegion` actor extracts entity IDs. A singleton `ShardCoordinator` manages locations.
  ]
]

= Wrap-up

== Acknowledgement

#feature-block("Acknowledgement")[
  The material and the slides are derived from Roberto Casadei's works and from the
  Concurrent and Distributed Programming course by Gianluca Aguzzi.

  Originally focused on Akka, these slides have been adapted to present the modern
  Apache Pekko ecosystem.
]

#v(1em)

#feature-block("References")[
  - Apache Pekko Documentation: #link("https://pekko.apache.org/docs/pekko/current/")[pekko.apache.org/docs/]
  - Pekko Remoting: #link("https://pekko.apache.org/docs/pekko/current/remoting-artery.html")[remoting-artery.html]
  - Pekko Serialization: #link("https://pekko.apache.org/docs/pekko/current/serialization.html")[serialization.html]
  - Pekko Cluster Specification: #link("https://pekko.apache.org/docs/pekko/current/typed/cluster-concepts.html")[typed/cluster-concepts.html]
  - Pekko Cluster: #link("https://pekko.apache.org/docs/pekko/current/typed/cluster.html")[typed/cluster.html]
  - Pekko Typed Routers: #link("https://pekko.apache.org/docs/pekko/current/typed/routers.html")[typed/routers.html]
]
