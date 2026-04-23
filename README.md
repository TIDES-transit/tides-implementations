# TIDES Implementations

Open-source implementations of the Transit Integrated Data Exchange Specification ([TIDES](https://github.com/TIDES-transit/TIDES)) by transit agencies, vendors, and research institutions.

## What this repository is

This repository is a shared space for people and organizations implementing TIDES to make their work public. It is community-built, loosely organized, and open to a wide range of contributions.

A contribution can be as small as a one-page README that names an agency, its primary contact, and a sentence about what they are building, or as substantial as a full implementation codebase with supporting documentation. Architecture notes, sample data pipelines, dbt models, validation scripts, case studies, and reference code are all welcome. Share what you can share.

The goal is a single, easy-to-browse place where anyone curious about who is working with TIDES in the wild can see the current landscape, find a point of contact, and learn from peers.

## How it is organized

Contributions are grouped by contributor type in category folders at the top level of the repository:

- `agencies/` for transit agencies, authorities, and other public-sector operators
- `vendors/` for software vendors, consultancies, and commercial implementers

Inside the appropriate category folder, each contributor has their own subfolder named after the organization. The structure inside that subfolder is up to the contributor, but a `README.md` at the root of the subfolder is required and should cover:

- The organization's name and a short description
- A primary contact (name, role, email or GitHub handle)
- What the implementation covers (which TIDES tables, which data sources, which analysis use cases)
- Any pointers to related resources (case studies, blog posts, public dashboards)

The starting set of category folders is intentionally small. If your organization does not fit neatly into `agencies/` or `vendors/`, please open an issue or start a discussion; the repository's categories will grow based on community feedback.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full contribution process.

## Current implementations

Contributions will be listed here as they are added. If you are working with TIDES and would like to be listed, please open an issue or submit a pull request.

## Stewardship and maintenance

This repository is stewarded by [MobilityData](https://mobilitydata.org) as part of the TIDES project, with oversight from the [TIDES Board](https://github.com/TIDES-transit/TIDES/blob/main/docs/governance.md).

**What stewardship means here:**

- MobilityData maintainers review incoming pull requests for tone, clarity, and alignment with the repository's purpose.
- Each contributing organization is responsible for maintaining its own subfolder. Code in a subfolder reflects the contributing organization's work, not a MobilityData-maintained product.
- The TIDES Board sets governance policy for the repository as a whole. The Board does not review every contribution.

**What stewardship does not mean:**

- MobilityData does not guarantee support, bug fixes, or ongoing development of any contributed code.
- Each implementation is provided by its contributor. Questions about a specific implementation should be directed to the contact listed in that subfolder's README.

## License and copyright

All contributions to this repository are released under the [Apache License 2.0](LICENSE).

Each contributing organization retains copyright for the code and content it submits. The Apache 2.0 license grants downstream users broad rights to use, modify, and redistribute the code, including in commercial products. Under a permissive license, the identity of the copyright holder has limited practical effect on downstream use; the intent is to make TIDES implementation work as widely reusable as possible.

Contributing organizations may, at their discretion, assign governance responsibilities for their contributions to the TIDES Board without transferring copyright.

See each subfolder for the specific copyright notice on that organization's code.

## Related resources

- [TIDES specification](https://github.com/TIDES-transit/TIDES), the core data specification
- [TIDES project website](https://tides-transit.org)
- [Awesome TIDES](https://github.com/TIDES-transit/awesome-list), a curated list of TIDES tools and resources

## Code of conduct

All participants in this repository are expected to follow the [TIDES Code of Conduct](CODE_OF_CONDUCT.md).

## Contact

Questions about the repository as a whole, or about contributing, can be sent to [tidestransit@gmail.com](mailto:tidestransit@gmail.com) or raised as a GitHub issue.
