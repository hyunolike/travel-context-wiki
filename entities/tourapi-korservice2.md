---
title: TourAPI KorService2
created: 2026-08-03
updated: 2026-09-22
type: entity
tags:
  - tourapi
  - openapi
  - public-data
sources:
  - raw/public-tourism-api/2026-openapi-briefing.txt
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/api-contract-v4.md
confidence: medium
contested: true
contradictions: []
---

# TourAPI KorService2

TourAPI KorService2 is the Korean tourism information service that travel services can use for attraction details, coordinates, images, and introduction fields.

The briefing shows that tourism details are provided through multiple operations, including common information, introduction information, repeated information, and image information. Consumer services should combine these operations rather than expect a custom list operation.

## Service Use

- Attraction search
- Attraction detail
- Coordinates for distance and map display
- Images and overview text

## Open Questions

- Final parameter names for legal-dong and classification-code replacement operations. The v4 consumer contract uses `ldongRegnCd`, `ldongSignguCd`, and `lclsSystm1` to `lclsSystm3` in place of the deprecated `areaCode`, `sigunguCode`, and `category`, but marks them provisional until spike item B5 checks them against the KorService2 manual. ^[raw/service-snapshots/hanjeok/api-contract-v4.md]
- Whether those legal-dong codes moved on 2026-07-01. [[regional-visitor-api]] shows Gwangju, South Jeolla, and part of Incheon under new district codes from that date. Nothing captured here says whether TourAPI followed, and a consumer keyed on pre-July codes would miss those regions if it did.
- Whether every target attraction has stable `contentId` compatibility with congestion data.

## Related Pages

- [[raw-derived-data-separation]]
- [[congestion-forecast-api]]
- [[related-attraction-api]]
