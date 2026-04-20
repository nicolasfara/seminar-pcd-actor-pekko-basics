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
      - *Pekko Remote Artery*: Location transparency, configuration, and serialization
      - *Pekko Clustering*: Cluster membership, gossiping, and failure detection
      - *Advanced Facilities*: Receptionist, Group Router, Distributed Data, and Sharding
    ],
  )
]

= Pekko Remote Artery

== Artery Remoting

#feature-block("Supersedes Classic Remoting")[
  (Artery) Remoting is the support by which actor systems on different nodes can
  talk to each other in a peer-to-peer fashion.
]

#components.side-by-side(columns: (1fr, 1fr), gutter: 1em)[
  #note-block("Location transparency")[
    No API difference between local or remote systems. `ActorRef`s to remote actors look exactly like those to local actors.
  ]
][
  #note-block("Serialization")[
    For interaction across a network, messages must be de/serialisable.
  ]
]

#v(0.5em)

#warning-block("Not meant to be used directly!")[
  Use higher-level modules like #bold[Pekko Cluster] utilities or technology-agnostic protocols
  such as HTTP and gRPC (cf. Pekko HTTP and Pekko gRPC).
]

== Configuration

We can configure Artery Remoting in `application.conf`:

#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko {
  actor {
    provider = remote // local or remote or cluster
    serialization-bindings {
      "it.unibo.pcd.pekko.Message" = jackson-cbor // serialization binding
    }
  }
  remote { // remote configuration
    artery {
      transport = tcp # aeron-udp, tls-tcp
      canonical.hostname = "127.0.0.1" // in real deployments, external IP
      canonical.port = 25520
    }
  }
}
```

== Acquiring references to remote actors

You can use a remote `ActorRef` exactly as a local one (i.e, `ref ! msg`) ... \
... But you need to obtain the `ActorRef` first!

#feature-block("Two potential ways:")[
  - *Passing an `ActorRef` in a message*: An actor on node A sends its `ActorRef` to an actor on node B.
  - *Receptionist*: In Pekko Typed, the `Receptionist` can be used for registering and discovering `ActorRef`s across the cluster.
]

#note-block("Legacy Note")[
  In Pekko/Akka Classic, this was supported through `actorSelection` (retrieving an `ActorRef` from a URL like `pekko://sys@host:port/user/actor`). In Typed, the `Receptionist` is the preferred mechanism.
]

== Serialization

In order to send messages to remote peers, you should devise your serialization policy.

#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko {
  actor {
    provider = remote // local or remote or cluster
    serializers { // key value map to associate name to serializers
      // Defaults..
      jackson-json = "org.apache.pekko.serialization.jackson.JacksonJsonSerializer"
      jackson-cbor = "org.apache.pekko.serialization.jackson.JacksonCborSerializer"
      proto = "org.apache.pekko.remote.serialization.ProtobufSerializer"
    }
    serialization-bindings { // map to link root message interface to serializer
      "it.unibo.pcd.pekko.Message" = jackson-cbor
    }
  }
}
```

Include the dependency on your serialisers:
```scala
libraryDependencies += "org.apache.pekko" %% "pekko-serialization-jackson" % PekkoVersion
```

== Delivery guarantees, remote watch, and quarantine

Pekko guarantees: (1) #bold[at-most-once delivery]; and (2) #bold[message ordering] between pairs of actors.
Artery uses TCP or Aeron as a "reliable" underlying message transport.

#warning-block("Cases when messages may not be delivered")[
  - During a network partition (TCP connection / Aeron session broke)
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

== Pekko Cluster Specification (1/2)

#feature-block("Overview")[
  Pekko Cluster provides a #bold[fault-tolerant decentralized peer-to-peer based Cluster Membership Service] with no single point of failure or single point of bottleneck. It does this using gossip protocols and an automatic failure detector.
]

#feature-block("Motivation")[
  Pekko Cluster allows for building distributed applications, where one application or service spans multiple nodes (in practice multiple `ActorSystem`s).
]

/ node: logical member of cluster, identified by `hostname:port:uid` (there could be multiple nodes on the same physical machine)
/ cluster: set of nodes joined together through Cluster Membership Service
/ leader: cluster node that manages cluster convergence and membership state transitions

== Pekko Cluster Specification (2/2)

#components.side-by-side(columns: (1.5fr, 1fr), gutter: 1em)[
  #feature-block("Cluster membership: how it works")[
    - #bold[Vector clocks] are used to reconcile and merge differences in cluster state during gossiping.
    - #bold[Convergence]: when all nodes are in the seen set for current cluster state.
    - Note: convergence cannot occur when some node is unreachable.
    - A #bold[Split Brain Resolver] deals with partitions; can be configured with downing strategies.
    - A #bold[failure detector] is what tries to detect if a node is un/reachable.
  ]
][
  #note-block("Gossip Protocol")[
    Nodes exchange state information to ensure eventually consistent membership across the cluster.
  ]
]

== Pekko Cluster: basic usage (1/2)

```scala
val PekkoVersion = "1.0.2"
libraryDependencies ++= Seq(
  "org.apache.pekko" %% "pekko-cluster-typed" % PekkoVersion,
  "org.apache.pekko" %% "pekko-serialization-jackson" % PekkoVersion
)
```

The Cluster extension gives you access to management tasks such as Joining, Leaving and Downing and subscription of cluster membership events such as `MemberUp`, `MemberRemoved` and `UnreachableMember`.

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

#codly(
  header: [`application.conf`],
  header-cell-args: (align: center, ),
)
```hocon
pekko {
  actor.provider = "cluster"
  remote.artery.canonical {
    hostname = "127.0.0.1"
    port = 2551
  }
  cluster {
    seed-nodes = [
      "pekko://ClusterSystem@127.0.0.1:2551",
      "pekko://ClusterSystem@127.0.0.1:2552"
    ]
    downing-provider-class = "org.apache.pekko.cluster.sbr.SplitBrainResolverProvider"
  }
}
```

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
} else {
  // spawn frontend or other roles
}
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
  The material and the slides are derived from Roberto Casadei works and from the
  Concurrent and Distributed Programming course by Gianluca Aguzzi.

  Originally focused on Akka, these slides have been adapted to present the modern
  Apache Pekko ecosystem.
]

#v(1em)

#feature-block("References")[
  - Apache Pekko Documentation: #link("https://pekko.apache.org/docs/pekko/current/")[pekko.apache.org/docs/]
  - Pekko Remoting: #link("https://pekko.apache.org/docs/pekko/current/remoting-artery.html")[remoting-artery.html]
  - Pekko Cluster: #link("https://pekko.apache.org/docs/pekko/current/typed/cluster.html")[typed/cluster.html]
]
