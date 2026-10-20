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
- [References](#references)
-->

## Purpose

Severity says how badly a defect hurts the people who use pyck: tenants,
their users and the operators who run it. It is set on every Defect, in the
organization-level Severity field (High, Medium, Low); how to set the field is
in [issues.md](issues.md#other-rules).

Severity is not priority. Priority says when a defect gets fixed and depends
on plans, releases and promises; it is decided separately. A High defect is
usually fixed soon, but the field records the impact, not the schedule.

The criteria below follow published severity policies of other engineering
organizations; each one names its sources, [Sources](#sources) quotes the
wording it rests on, and [References](#references) lists the documents.
Criteria no published policy backs are marked as pyck's own rules.

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

Medium as the normal level follows [Mozilla Bugzilla](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity) ("S3 (Normal)")
and [Google Issue Tracker](https://developers.google.com/issue-tracker/concepts/issues) ("P2 ... is the default priority level").
The workaround rule follows [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) ("severity::3: Broken feature
with a workaround") and [Google Issue Tracker](https://developers.google.com/issue-tracker/concepts/issues) ("would be P0 or P1 but
has a reasonable workaround"). Rule 5 is pyck's own: bug bounty programs such
as [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy) rate a flaw nobody can exploit as informational, and
pyck keeps it at Medium so it is not forgotten.

## High

| Id | Criterion | Example | Sources |
| --- | --- | --- | --- |
| H1 | Data a user would act on is wrong: wrong or missing rows, a wrong count or aggregate, a link to the wrong record, a write that is lost, duplicated or silently undone. | A stock total includes another repository's items. | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity), [Mozilla](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity), [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) |
| H2 | Tenant isolation is broken: a request of one tenant reads, changes or references another tenant's data, or disrupts its caches, events, workflows or data access. This holds also for a caller with access to both tenants, unless the caller explicitly asked for several tenants. | A query returns rows of a tenant the caller did not select. | [Microsoft](https://www.microsoft.com/en-us/msrc/olsbugbar), [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy), [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) |
| H3 | A credential leaks: a token, an API key, a password or a private key. | A bearer token appears in a log line or a response. | [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy) |
| H4 | Authentication or authorization can be bypassed today. | A Reader can run a mutation that needs Writer. | [Microsoft](https://www.microsoft.com/en-us/msrc/olsbugbar) |
| H5 | A core flow does not work for all tenants or a large share of them, and there is no reasonable workaround: a service is down, valid use crashes it, or a core flow (login, stock, movements, picking, receiving) fails. | Every `createMovement` fails. | [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels), [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity), [Google](https://developers.google.com/issue-tracker/concepts/issues) |
| H6 | Events or signals are silently lost in normal operation, after a restart or after a misconfiguration. | A consumer recreated after downtime skips the events of that downtime. | pyck's own rule |

## Low

| Id | Criterion | Example | Sources |
| --- | --- | --- | --- |
| L1 | Cosmetic: wording, formatting, a misleading but harmless message. | A typo in an error message. | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity), [Mozilla](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity), [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) |
| L2 | Bad input only hurts the caller's own request or own records, without harm to other callers, tenants or shared services. | A NUL byte in an id stalls that one request. | [Microsoft](https://www.microsoft.com/en-us/msrc/olsbugbar); pyck's own rule beyond that |
| L3 | Internal error text, a stack trace or software versions are shown to the caller, without another tenant's data and without a secret. | A raw SQL error in a GraphQL error message. | [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy) |
| L4 | A feature is inconvenient but works, and no data is wrong. | A filter needs a second request to narrow the result. | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) |
| L5 | The defect is in the documentation only and no product behaviour is wrong. | A wrong example on a docs page. | pyck's own rule |

## Stays Medium

These are Medium by the rule, written down because they are often rated
wrong:

- A feature is broken but a reasonable workaround exists.
- A security weakness that nobody can exploit today.
- Events or signals are lost, duplicated or delayed only while a dependency
  (database, message broker, workflow engine) is down or unreachable.
- A crash or a wrong result only for rare edge-case input of other callers.
- Performance is worse but still usable ([Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) SEV 3:
  "Usable performance degradation").

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
[pyck-triage](https://github.com/pyck-ai/pyck-triage/blob/main/docs/severity.md)
applies these criteria. It leaves the field empty when it is not sure, and a
human then rates the defect by this guideline.

## Sources

The wording each criterion rests on, quoted from the documents in
[References](#references):

| Criterion | Source | Wording |
| --- | --- | --- |
| Medium as normal | [Mozilla Bugzilla](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity) | "S3 (Normal) Blocks non-critical functionality or a work around exists" |
| Medium as normal | [Google Issue Tracker](https://developers.google.com/issue-tracker/concepts/issues) | P2: "It is the default priority level." |
| H1 data | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) | severity::1: "Broken feature with no workaround or any data-loss."; example "Data corruption/loss." |
| H1 data | [Mozilla Bugzilla](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity) | S1: "causes data loss" |
| H1 data | [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) | SEV 1 example: "Customer data loss" |
| H2 tenant isolation | [Microsoft](https://www.microsoft.com/en-us/msrc/olsbugbar) | Improper Access Control, Critical: "Missing access controls exposes sensitive data from another customer" |
| H2 tenant isolation | [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy) | Cross-Tenant PII Leakage/Exposure: P1 |
| H2 tenant isolation | [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) | SEV 1 example: "Confidentiality or privacy is breached" |
| H3 credential | [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy) | Disclosure of Secrets, For Publicly Accessible Asset: P1; Publicly Accessible IAM Credentials: P1 |
| H4 bypass | [Microsoft](https://www.microsoft.com/en-us/msrc/olsbugbar) | Authentication Issues, Critical: "Vulnerability allowing attacker to authenticate as another highly privileged user or cross tenant without victim's interaction" |
| H5 outage | [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) | SEV 1: "down for all customers"; SEV 2: "unavailable for a subset of customers" |
| H5 outage | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) | severity::1: "Impacts 20% or more of users ... without an available workaround" |
| H5 outage | [Google Issue Tracker](https://developers.google.com/issue-tracker/concepts/issues) | P0: "makes a critical function of the product to be unavailable for everyone, without any known workaround" |
| Workaround | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) | severity::3: "Broken feature with a workaround." |
| Workaround | [Google Issue Tracker](https://developers.google.com/issue-tracker/concepts/issues) | P2: "An issue that would be P0 or P1 but has a reasonable workaround" |
| L1 cosmetic | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) | severity::4 examples: "Incorrect colors." "Misalignment." |
| L1 cosmetic | [Mozilla Bugzilla](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity) | S4: "minor significance, cosmetic issues, low or no impact to users" |
| L1 cosmetic | [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) | SEV 5: "Bugs or support issues that don't impact product usability" |
| L2 own request | [Microsoft](https://www.microsoft.com/en-us/msrc/olsbugbar) | Web Security Misconfiguration, Low: "denial of service for the user, requiring them to refresh the page" |
| L3 error text | [Bugcrowd](https://github.com/bugcrowd/vulnerability-rating-taxonomy) | Visible Detailed Error/Debug Page, Descriptive Stack Trace: P5; Software Versions Disclosed in Response Headers: P5 |
| L4 inconvenient | [GitLab](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity) | severity::4: "Functionality is inconvenient." |
| Stays Medium | [Atlassian](https://www.atlassian.com/incident-management/kpis/severity-levels) | SEV 3 example: "Usable performance degradation" |

## References

Read on 2026-10-20. A source that changes its wording does not change this
guideline; a change here is a reviewed pull request.

- [GitLab Handbook, Issue Triage: Severity](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity), GitLab Inc.
- [Bugzilla Field Descriptions: bug_severity](https://wiki.mozilla.org/BMO/UserGuide/BugFields#bug_severity), Mozilla.
- [Google Issue Tracker: Issues, issue fields](https://developers.google.com/issue-tracker/concepts/issues), Google.
- [Understanding incident severity levels](https://www.atlassian.com/incident-management/kpis/severity-levels), Atlassian.
- [Microsoft Vulnerability Severity Classification for Online Services](https://www.microsoft.com/en-us/msrc/olsbugbar),
  Microsoft Security Response Center.
- [Vulnerability Rating Taxonomy](https://github.com/bugcrowd/vulnerability-rating-taxonomy), Bugcrowd (the taxonomy file
  `vulnerability-rating-taxonomy.json` in that repository).

Looked for and not found: Netflix and Cloudflare publish no severity policy
for defects. AWS publishes severity levels for support cases only
("General guidance" to "Business-critical system down"), not for defects.
