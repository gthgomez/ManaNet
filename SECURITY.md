# Security Policy — ManaNet

## Project status: proprietary, not open source

ManaNet is proprietary software. The source is published for source visibility and transparency only. The repository [LICENSE](LICENSE) is a proprietary license notice that grants no permission to copy, modify, redistribute, or build derivative works. The [README](README.md) states this in its opening banner.

Because no permission to use the code has been granted, a defect in it is not a "vulnerability" in the open-source sense. It is a question about unauthorized use of unlicensed software, and that question belongs to the owner of the code, not to a public disclosure process. This file exists so the boundary is stated plainly instead of left to inference.

## What this repository does not offer

- **No security support.** The maintainer does not triage, investigate, or remediate security reports for ManaNet.
- **No coordinated disclosure program.** There is no embargo, no safe harbor, and no private disclosure window.
- **No bug bounty.** No reward is offered.
- **No response-time commitment.** There is no SLA and no support window.
- **No supported versions.** No release is a supported security-fix channel.

## Project shape and what that implies

ManaNet is a single-player Godot 4.6 tower-defense game built from GDScript. This repository contains the game project, its art and data, and a test suite. It contains no server component, no account system, and no deployment credentials.

That shape does not make the code safe. A local game can still have parsing defects, unsafe file handling, or dependencies with their own problems. It does mean there is no hosted service for a reporter to attack and no user data store to breach. Local save files are the user's own data on the user's own machine.

## What this project has documented about itself

The repository's own records are in [docs/](docs/) and cover identity, UI, theme, and playability work. They are cited for completeness; they are not security attestations.

## Reporting a genuine concern

If you believe you have found a genuine security concern, the honest position is that the maintainer has not accepted a support obligation, so there is no guaranteed response. If you choose to raise it anyway:

- Prefer GitHub's private vulnerability reporting for this repository (the **Security** tab → **Report a vulnerability**), if it is available to you.
- Otherwise contact the repository owner through their public profile at <https://github.com/gthgomez>.
- Do not open a public issue, and do not include working exploit code or third-party personal data in a public report.
- You receive no service commitment, no bounty, and no assurance of a fix.

## Visibility is not permission

The repository being public creates no support obligation. Publishing source does not grant a license, does not create a support contract, and does not make the maintainer a vendor to you. Opening an issue or submitting a pull request grants you no rights and creates no partnership; contributions are not accepted for reuse, and no license is granted over anything you send here.

## Third-party dependencies

Third-party components, including the Godot engine and any third-party assets, remain under their own licenses and their own security policies. Issues in a dependency should be reported to that project, not here. This document does not extend to them.
