# Source version contract

Given canonical claims linked to raw snapshots, including contested/low confidence pages,
When a raw source or claim changes without refreshing the pinned contract,
Then validation and bundle metadata generation fail with needs-review.

Given a deliberate refresh after source changes,
When the contract is updated,
Then affected claims remain needs-review, never automatically reviewed.

Given the model-choice history whose experiment files were never captured,
When provenance is validated,
Then its explicit legacy exception remains unverified and is not presented as experiment evidence.

Given identical file bytes and the same source history,
When full bundles and metadata are built twice,
Then the outputs match byte for byte and metadata binds bundle, documents, sources and claims.

Given unrelated valid citation paths,
When a congestion explanation is validated by the consumer,
Then membership alone does not satisfy the congestion policy topic.
