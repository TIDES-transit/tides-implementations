# Contributing

Thank you for your interest in contributing to `tides-implementations`. This repository exists to make TIDES implementation work visible to the community. The process for adding an implementation is intentionally light.

## Who can contribute

Transit agencies, public-sector consortia, vendors, consultants, researchers, and academic institutions are all welcome to contribute. If you are implementing or working with the [TIDES specification](https://github.com/TIDES-transit/TIDES) in any form, there is a place for you here.

## What a contribution looks like

A contribution is a new subfolder at the top level of this repository, named after your organization. The folder can contain as much or as little as you are willing to publish. At a minimum, it should contain a `README.md` that answers:

- **Who:** your organization's name and a short description
- **Who to contact:** name, role, email or GitHub handle for someone who can answer questions about the implementation
- **What:** which parts of TIDES you are implementing, what data sources you are using, and what the implementation is for (reporting, analytics, quality assurance, service planning, etc.)
- **Where to learn more:** links to blog posts, case studies, public dashboards, or other related resources

Beyond the README, you are welcome to include source code, architecture diagrams, sample configuration files, dbt models, transformation scripts, validation tooling, or anything else that helps others understand and learn from your work. Nothing beyond the README is required.

## How to submit a contribution

1. Fork this repository, or request write access from the maintainers if you plan to contribute regularly.
2. Create a branch named for your organization (for example, `ac-transit/initial-publication`).
3. Add a top-level subfolder with your organization's slug (for example, `ac-transit/`) and fill it with your README and any other content you want to share.
4. Open a pull request against `main`. In the PR description, introduce your organization briefly and note any review feedback you would particularly value.
5. A maintainer will review the PR for tone, clarity, and alignment with the repository's purpose. Substantive review of your implementation's technical content is not part of the maintainer review process; that is your organization's work to publish as you see fit.

If you would prefer to coordinate with a maintainer before opening a PR, please open an issue or email [tidestransit@gmail.com](mailto:tidestransit@gmail.com).

## Copyright and licensing

All contributions to this repository are released under the [Apache License 2.0](LICENSE). By opening a pull request, you are confirming that:

- You have the authority to release the contributed code and content under Apache 2.0.
- Your organization retains copyright for its contributions. This repository does not require or request copyright transfer.
- You understand that once published, the code and content are available to anyone under the terms of the Apache 2.0 license.

Each subfolder should include an appropriate copyright notice in its README or as a separate `NOTICE` file. For example:

```
Copyright YYYY [Contributing Organization]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

Source files that include Apache 2.0 license headers are welcome. If you are unsure about how to apply license headers to your contribution, the maintainers can help.

## Review and merge

- Pull requests are reviewed by TIDES project maintainers at MobilityData.
- Review typically focuses on readability, naming, subfolder structure, and ensuring no sensitive internal content has been published inadvertently (credentials, internal URLs, personal email addresses other than published contacts).
- Once a pull request is approved, a maintainer will merge it.
- After your contribution is merged, you can propose updates at any time with a new pull request against `main`.

## Maintenance expectations

Each contributing organization is responsible for maintaining its own subfolder. If you no longer plan to keep your contribution current, you are welcome to say so in your subfolder's README and leave the content in place as an archival reference, or to open a pull request removing the folder.

The maintainers of this repository do not monitor, update, or fix content inside contributor subfolders.

## Code of conduct

All participants are expected to follow the [TIDES Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## Questions

For general questions about contributing, email [tidestransit@gmail.com](mailto:tidestransit@gmail.com) or open a GitHub issue.
