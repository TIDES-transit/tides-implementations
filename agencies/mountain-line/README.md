# Mountain Line (MUTD)

Mountain Line is the [Missoula Urban Transportation District (MUTD)](https://mountainline.com/about/), the public transit agency serving Missoula, Montana. Mountain Line operates 29 fixed-route buses and 17 paratransit vehicles, has been fare-free since January 2015, and runs a near-fully-electric fleet. It was named the 2025 CTAA Small Urban Agency of the Year and the 2021 APTA Outstanding Public Transportation System (top system under 4 million trips in North America).

This subfolder is Mountain Line's entry in `tides-implementations`. Its primary purpose is to point to the open-source TIDES tooling being developed for Mountain Line's data pipeline, so that other small and mid-sized agencies can fork, adapt, or learn from it.

## Who to contact

Garin Wally — Transit Analyst, Mountain Line
[gwally@mountainline.com](mailto:gwally@mountainline.com) · GitHub: [@WindfallLabs](https://github.com/WindfallLabs)

## What's being implemented

Mountain Line is building a Python-based "analyst on a laptop" implementation pattern for TIDES — Level 0 in the [TIDES Common Architecture Framework](https://tides-transit.org). The work in progress includes:

- **NTD reporting pipeline.** Co-designed with MobilityData as the small-urban anchor of a multi-agency NTD reporting pilot framework (alongside WMATA's large-agency pilot). The framework runs TIDES-derived NTD metrics in parallel with existing reporting for FY2027, with phased coverage of fixed-route monthly metrics, demand-response metrics, and full annual rollup.
- **Open-source schema validation library.** [`polar-tides`](https://github.com/WindfallLabs/polartides) — a Python library for validating [Polars](https://pola.rs/) DataFrames against TIDES table schemas, built on [`dataframely`](https://github.com/Quantco/dataframely). All TIDES tables covered as `dataframely.Schema` classes with column types, nullability constraints, and value-enforcement rules for enum fields. Released as alpha (v0.1.0a1) under the MIT License.
- **Open-source orchestration library.** [`little_pipelines`](https://github.com/WindfallLabs/little_pipelines) — a minimal-dependency Python library for building and executing data pipelines. Decorator-based task definitions with automatic dependency resolution via `graphlib.TopologicalSorter`. Targets the analyst-on-a-laptop end of the spectrum, intentionally distinct from enterprise tools (Airflow, Prefect, Dagster, dbt). MIT-licensed.

## Data sources being integrated

| Source | Vendor / system | TIDES tables fed |
|---|---|---|
| CAD/AVL | ETA Transit (replacing Clever) | `vehicle_locations`, `trips_performed` |
| APC | Hardware on every fixed-route bus, statistically processed by Swiftly | `passenger_events`, `stop_visits` |
| Demand-response | Via Transportation (`Ride the Line — Missoula`) | `trips_performed`, derived DR metrics |
| Maintenance / fleet | RTA (Ron Turley Associates) | supporting reference data |
| Schedule | Self-published GTFS / GTFS-RT | linkage via `trip_id_scheduled`, `stop_id` |

## What's published here (and what's not)

This subfolder is currently a **pointer entry**. The active development happens in the linked external repositories above; Mountain Line's working code lives there rather than being copied into this repo. As the implementation matures, additional materials may be added here directly — sample pipeline configurations, transformation worked examples, a case study writeup, or contributions of MUTD-specific reference data once it's appropriate to share publicly.

If you're an analyst at a small or mid-sized agency exploring TIDES, the `polar-tides` and `little_pipelines` repos linked above are the most useful starting points. Both are MIT-licensed and intentionally minimal in their dependencies.

## License

Copyright 2026 Missoula Urban Transportation District

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Note that the linked external libraries (`polar-tides`, `little_pipelines`) are licensed independently by their author under the MIT License. Apache 2.0 and MIT are both permissive licenses and are fully compatible.

## Related resources

- [TIDES specification](https://github.com/TIDES-transit/TIDES)
- [TIDES Common Architecture Framework](https://tides-transit.org)
- [Mountain Line website](https://mountainline.com/about/)
- [`polar-tides` on GitHub](https://github.com/WindfallLabs/polartides)
- [`little_pipelines` on GitHub](https://github.com/WindfallLabs/little_pipelines)
