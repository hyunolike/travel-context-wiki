---
title: TourAPI KorService2
created: 2026-08-03
updated: 2026-08-03
type: entity
tags:
  - tourapi
  - openapi
  - public-data
sources:
  - raw/openapi-briefing/2026-openapi-briefing.txt
  - raw/hanjeok-design/design-v3.md
confidence: medium
contested: true
contradictions: []
---

# TourAPI KorService2

TourAPI KorService2 is the Korean tourism information service used by Hanjeok for attraction details, coordinates, images, and introduction fields.

The briefing shows that tourism details are provided through multiple operations, including common information, introduction information, repeated information, and image information. Hanjeok should combine these operations rather than expect a custom list operation.

## Hanjeok Use

- Attraction search
- Attraction detail
- Coordinates for distance and map display
- Images and overview text

## Open Questions

- Final parameter names for legal-dong and classification-code replacement operations.
- Whether every target attraction has stable `contentId` compatibility with congestion data.

## Related Pages

- [[raw-derived-data-separation]]
- [[congestion-forecast-api]]
- [[related-attraction-api]]

