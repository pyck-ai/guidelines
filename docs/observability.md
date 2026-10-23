# Observability Guidelines

Rules for the logs, metrics, traces and alerts of a service. They name no vendor, so they hold for any backend. The org's SDK for traces, metrics and logs is OpenTelemetry. What telemetry must never contain (secrets, personal data) is in [security-review.md](security-review.md).

## Start from the on-call questions

Applies when you add logging, a metric, a span or an alert.

Telemetry without a question is noise. Before you instrument a feature, write down the 2 to 4 questions an on-call engineer will ask about it, for example "what share of payments succeed on the first attempt?". Every signal you add answers one of them. If you cannot name the questions, you are not ready to instrument.

Pick the signal by the question:

- A metric says that something is wrong, in aggregate.
- A trace says where the time went across services.
- A log says why one case went wrong.

## Logs

Applies when you add or change a log line.

- Log events, not prose. Each line is structured (JSON) with a stable event name and machine-readable fields, such as `payment_failed` with `provider` and `attempt`. A message built by string interpolation cannot be queried.
- Use the levels the same way everywhere. `error`: an invariant broke and someone may need to act. `warn`: degraded but handled, such as a retry that succeeded. `info`: a significant business event. `debug`: diagnostic detail, off in production.
- Generate or accept a correlation id at the system boundary and put it on every log line, every span and every outbound call. Carry it across async boundaries too (HTTP headers, queue message metadata). Without it, one request cannot be rebuilt from interleaved lines.
- When several entry points write to one log (a scheduler, a replay endpoint, a manual run), set an entry-point field where the run starts and propagate it with the correlation id. Otherwise a line can only be attributed by guessing from outside records.
- Allowlist the fields you log. Never log a whole request or response body or an auth header. For a call to an external service, log metadata only: endpoint, status, latency, attempt count.
- Read real output once. A field that prints as `[object Object]` is not structured.

## Metrics

Applies when you add or change a metric or a label.

- Measure rate, errors and duration for every endpoint and every external dependency. Measure utilization, saturation and errors for every resource that can fill up (queue, pool, host). For a queue, add its depth and its processing time.
- Record latency as a histogram and read p50, p95 and p99. An average hides the 1% of users with a terrible time.
- Every distinct label combination is a separate time series, so labels come from small, fixed sets: route template, status class (`5xx`, not `503`), provider name.
- Never use an unbounded value as a label: user id, tenant id, email, raw URL, request id or error text. That detail belongs in logs and traces.

## Traces

Applies when you add or change a span or trace propagation.

- Propagate the W3C trace context (`traceparent`, `tracestate`) on every outbound call, and extract it from every inbound request. Put it in queue message metadata, or the trace ends at the queue.
- Rely on automatic instrumentation for HTTP, gRPC and database clients. Add a manual span only around a meaningful unit of work, with the attributes on-call will filter by.
- Sample at the head at a low default rate. Keep every errored trace where tail sampling is available.

## Alerts

Applies when you add or change an alert.

- Alert on symptoms users feel, such as error rate, p99 latency or queue age. Causes (CPU, disk, one restarted pod) belong on a dashboard, because a cause alert fires when nothing is wrong and misses the failure you did not predict.
- Make every alert actionable. Delete an alert whose answer is "ignore it, it heals itself", and one that fires daily and is acknowledged without action.
- Give every alert an owner and a runbook link. A runbook has three lines at minimum: what the alert means, the first query to run, and who to escalate to. Update the runbook when an incident shows it was wrong.
- Justify each threshold and duration by an SLO or by past data, and write that reason next to the alert. A guessed threshold is a future false page.
- Use two severities. A page means users are affected and someone acts now. A ticket means degradation that someone acts on this week.
- When an alert fires on a production incident, load the `incident` skill from [pyck-ai/incidents](https://github.com/pyck-ai/incidents), which owns the triggers and the incident severities. After it is resolved, the `postmortem` skill writes it up.

## Version attributes

Applies when you add a service, a client or an about page.

Every component exposes its identity: a backend serves `/version` and logs it at startup, a web app serves `/version.json`, and a mobile app shows it in its about panel. Put the Component Version on the telemetry as a resource attribute. An untagged build reports its `git describe` output. The fields and what they mean are in [releases.md](releases.md#build-identity). A client sends its name and Component Version on every API call, so a request can be traced to the client build that made it.

## Verify the telemetry

Applies before you call instrumentation done.

Instrumentation is code and can be wrong. Force an error in staging and find it by correlation id. Send test traffic and check that the series carry the expected labels and sane values. Follow one request through the trace across every service and look for broken spans. Fire each new alert once and confirm it reaches the right channel and its runbook link works.
