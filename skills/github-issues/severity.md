<!-- Generated from docs/severity.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/severity.md and run task generate. -->
# Severity Guidelines

<!-- toc
## Contents

- [Purpose](#purpose)
- [The rule](#the-rule)
- [High](#high)
- [Low](#low)
- [Stays Medium](#stays-medium)
- [Rating a defect](#rating-a-defect)
- [Sources](#sources)
-->

## Purpose

Severity says how badly a defect hurts the people who use pyck: tenants,
their users and the operators who run it. It is set on every Defect, in the
organization-level Severity field (High, Medium, Low); how to set the field is
in [issues.md](~/.pyck/guidelines/docs/issues.md#other-rules).

Severity is not priority. Priority says when a defect gets fixed and depends
on plans, releases and promises; it is decided separately. A High defect is
usually fixed soon, but the field records the impact, not the schedule.

## The rule

1. Every defect is **Medium** unless a criterion below holds.
2. A defect is **High** when at least one [High](#high) criterion holds. High
   wins over Low.
3. A defect is **Low** only when a [Low](#low) criterion holds and no High
   criterion does.
4. When the impact is unclear, the defect stays Medium. Ask the reporter for
   the missing fact instead of guessing up or down.
5. A security vulnerability is never Low, also when nobody can exploit it
   today. The one exception is internal error text ([L3](#low)).

Judge the defect as it behaves in production, for valid use by callers who
are allowed to make the request. A workaround does not make a defect Low: it
only keeps a broken feature at Medium instead of High (see [H5](#high)).

## High

| Id | Criterion | Example |
| --- | --- | --- |
| H1 | Data a user would act on is wrong: wrong or missing rows, a wrong count or aggregate, a link to the wrong record, a write that is lost, duplicated or silently undone. | A stock total includes another repository's items. |
| H2 | Tenant isolation is broken: a request of one tenant reads, changes or references another tenant's data, or disrupts its caches, events, workflows or data access. This holds also for a caller with access to both tenants, unless the caller explicitly asked for several tenants. | A query returns rows of a tenant the caller did not select. |
| H3 | A credential leaks: a token, an API key, a password or a private key. | A bearer token appears in a log line or a response. |
| H4 | Authentication or authorization can be bypassed today. | A Reader can run a mutation that needs Writer. |
| H5 | A core flow does not work for all tenants or a large share of them, and there is no reasonable workaround: a service is down, valid use crashes it, or a core flow (login, stock, movements, picking, receiving) fails. | Every `createMovement` fails. |
| H6 | Events or signals are silently lost in normal operation, after a restart or after a misconfiguration. | A consumer recreated after downtime skips the events of that downtime. |

## Low

| Id | Criterion | Example |
| --- | --- | --- |
| L1 | Cosmetic: wording, formatting, a misleading but harmless message. | A typo in an error message. |
| L2 | Bad input only hurts the caller's own request or own records, without harm to other callers, tenants or shared services. | A NUL byte in an id stalls that one request. |
| L3 | Internal error text, a stack trace or software versions are shown to the caller, without another tenant's data and without a secret. | A raw SQL error in a GraphQL error message. |
| L4 | A feature is inconvenient but works, and no data is wrong. | A filter needs a second request to narrow the result. |
| L5 | The defect is in the documentation only and no product behaviour is wrong. | A wrong example on a docs page. |

## Stays Medium

These are Medium by the rule, written down because they are often rated
wrong:

- A feature is broken but a reasonable workaround exists.
- A security weakness that nobody can exploit today.
- Events or signals are lost, duplicated or delayed only while a dependency
  (database, message broker, workflow engine) is down or unreachable.
- A crash or a wrong result only for rare edge-case input of other callers.
- Performance is worse but still usable.

## Rating a defect

1. Read the report and its comments. Check every [High](#high) criterion; if
   one holds, the defect is High.
2. Otherwise check every [Low](#low) criterion; if one holds and the defect
   is not a security vulnerability (other than L3), it is Low.
3. Otherwise it is Medium.
4. Name the criterion (for example "H2") in a comment when you set High or
   Low, so the next reader can check it.
5. Never overwrite a severity somebody else set. Disagree in a comment.

The severity bot of
pyck-triage
applies these criteria. It leaves the field empty when it is not sure, and a
human then rates the defect by this guideline.

## Sources

The criteria follow what public severity policies agree on; H6, L2 and L5
are pyck's own rules.

| Criterion | Source and wording |
| --- | --- |
| Medium as the normal level | Mozilla calls S3 "(Normal) Blocks non-critical functionality or a work around exists" (Bugzilla fields); Google Issue Tracker: P2 "is the default priority level" (issue fields). |
| H1 data | GitLab severity::1 "Broken feature with no workaround or any data-loss", example "Data corruption/loss" (issue triage); Mozilla S1 "causes data loss"; Atlassian SEV 1 "Customer data loss" (severity levels). |
| H2 tenant isolation | Microsoft rates "Missing access controls exposes sensitive data from another customer" Critical (online services bug bar); Bugcrowd rates Cross-Tenant PII Leakage/Exposure P1 (VRT); Atlassian SEV 1 "Confidentiality or privacy is breached". |
| H3 credential | Bugcrowd: Disclosure of Secrets for a publicly accessible asset P1, Publicly Accessible IAM Credentials P1. |
| H4 bypass | Microsoft rates authenticating "as another highly privileged user or cross tenant without victim's interaction" Critical. |
| H5 outage | Atlassian SEV 1 "down for all customers", SEV 2 "unavailable for a subset of customers"; GitLab severity::1 "Impacts 20% or more of users ... without an available workaround"; Google P0 "unavailable for everyone, without any known workaround". |
| Workaround keeps it Medium | GitLab severity::3 "Broken feature with a workaround"; Google P2 "would be P0 or P1 but has a reasonable workaround". |
| L1 cosmetic | GitLab severity::4 examples "Incorrect colors. Misalignment."; Mozilla S4 "cosmetic issues, low or no impact to users"; Atlassian SEV 5 "don't impact product usability". |
| L2 own request | Microsoft rates a "denial of service for the user, requiring them to refresh the page" Low. |
| L3 error text | Bugcrowd: Descriptive Stack Trace P5, Software Versions Disclosed in Response Headers P5. |
| L4 inconvenient | GitLab severity::4 "Functionality is inconvenient". |
| Security never Low | pyck's own rule. Bug bounty programs rate a flaw nobody can exploit as informational; pyck keeps it Medium so it is not forgotten. |

Netflix and Cloudflare publish no severity policy for defects; AWS publishes
severity levels for support cases only.
