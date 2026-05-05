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


== Serialization

In order to send messages to remote peers, you must devise your serialization policy.

#small-code[
#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko.actor.provider = remote
pekko.actor.serialization-bindings {
  "it.unibo.pcd.pekko.Message" = jackson-cbor
}
```

Built-in serializers include `jackson-json`, `jackson-cbor`, and `proto`.

Include the dependency on your serializers:
```scala
libraryDependencies += "org.apache.pekko" %% "pekko-serialization-jackson" % PekkoVersion
```
]

== Remote Security

#feature-block("Protect remoting")[
  - Prefer `tls-tcp` when messages must be encrypted
  - Use mutual authentication between peers
  - Do not expose Artery directly on an untrusted network
]

#warning-block("Untrusted mode")[
  `pekko.remote.artery.untrusted-mode = on` blocks remote deployment, remote DeathWatch, system-stop style messages, and messages marked `PossiblyHarmful`.
]

#note-block("Trusted selection paths")[
  If you need limited actor-selection access, allow only specific paths with `pekko.remote.artery.trusted-selection-paths`.
]

== Delivery guarantees, remote watch, and quarantine

Pekko guarantees: (1) #bold[at-most-once delivery]; and (2) #bold[message ordering] between pairs of actors.
Artery uses TCP or Aeron as a "reliable" underlying message transport.

#warning-block("Cases when messages may not be delivered")[
  - During a network partition (TCP connection / Aeron session broken)
  - When sending too many messages without flow control (filling outbound queue)
  - On de/serialization failure
  - Exception in the remoting infrastructure
]

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
    - *Receptionist:* Registered actors will appear in the receptionist of other nodes of the cluster (via distributed-data).
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
  - Pekko Cluster Specification: #link("https://pekko.apache.org/docs/pekko/current/typed/cluster-concepts.html")[typed/cluster-concepts.html]
  - Pekko Cluster: #link("https://pekko.apache.org/docs/pekko/current/typed/cluster.html")[typed/cluster.html]
]
