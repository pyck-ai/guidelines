# SQL Guidelines

Rules for SQL text, its parameters and stored functions, in Go and in any other language. They apply to SQL a person writes: a raw query or statement, a hand-written migration, a stored function or procedure, a lock statement, a raw fragment passed into the query builder and any code that passes SQL fragments around. They apply to test code too, because test SQL gets copied into production code. SQL that a tool generates and nobody edits by hand (the ORM's own builder output, generated migration files) is out of scope. The review standard for injection is in [security-review.md](security-review.md#security-vulnerabilities); this doc owns the rule for SQL.

## Never assemble SQL text at runtime

Build no SQL text at runtime. Do not use `fmt.Sprintf`, string concatenation, `strings.Join`, `strings.Replace`, `strings.Builder`, `text/template` or any other interpolation. Do not write a helper that takes a SQL fragment as a string parameter: a filter, a lock mode, a table or column name, a placeholder list.

The rule holds even when every input today is a constant, ent field-name constants included. Three reasons:

- A helper that formats strings into SQL is one caller away from injection.
- String assembly is error prone: a missing space, a wrong placeholder number or a stray comma shows up in production, not at compile time.
- Text that varies per call stops the server from reusing its plan.

## Write SQL text as a constant or an embedded file

SQL text is one of these:

- a Go `const` string literal;
- a file embedded with `go:embed`.

A `const` built from other consts is fine. A `var` whose initialiser joins or formats strings is not allowed, whatever it joins.

## Put logic in a stored function

When one round trip must loop, branch or page over rows, write a stored function or procedure in an embedded `.sql` file and install it with a migration. Go then calls it with one constant statement and bind parameters. A Go transaction that runs a few constant statements is fine.

Precedent: `inventory.load_stock_rebase_snapshot` in `pyck-ai/pyck` replaced a Go-side scan that paged through the table ([PR 1410](https://github.com/pyck-ai/pyck/pull/1410)).

## Bind every value

Every value is a bind parameter: `$1`, `$2` and so on. Never write a value into the SQL text.

A list of variable length is one parameter, not many:

- `= ANY($2::uuid[])` with an array binding, or
- a jsonb array unpacked with `jsonb_array_elements`.

Never generate a `$2, $3, ...` list at runtime.

## Choose identifiers from a closed set

An identifier that must vary (a table, schema or partition name in DDL or maintenance code) comes from a closed set in Go. Use a `switch` that returns one constant statement per case, and reject any other name. A quoting helper (`pq.QuoteIdentifier`, `pgx.Identifier.Sanitize`, a project `QuoteIdentifier`) does not replace the closed set. Never quote an identifier with Go's `%q`: Go string quoting is not SQL identifier quoting.

For an open set (for example monthly partitions), move the DDL into a stored procedure that takes the name as a value. Inside it, dynamic SQL uses `format('%I', ...)` for identifiers and `EXECUTE ... USING` for values.

## Use the query builder where it can express the query

Where the query builder (ent) can express the query, use it. A raw fragment inside the builder counts as SQL text and follows every rule above: ent's `sql.Expr` and `sql.ExprP`, a predicate function that emits raw SQL, and `sqljson.DotPath` outside a repository's validated wrapper.

## Write stored functions that keep the tenant boundary

Raw SQL bypasses the ORM's privacy and tenant filters, so a function carries its own.

- Declare `SECURITY INVOKER` unless a written reason says otherwise.
- Put an explicit tenant predicate on every table the function reads or writes.
- Write one function per operation: a function is the unit Go calls and a migration replaces.
- Give the migration that adds a function a down that restores the previous body.

## Review SQL

Trace every string that reaches a method that takes SQL text back to its origin: `Exec`, `Query`, `QueryRow`, `Prepare`, their `Context` forms and `Raw` on `database/sql`, ent's driver and pgx, and pgx `SendBatch` and `CopyFrom`. A string that is neither a `const` nor an embedded file is Act on (see [code-review.md](code-review.md#findings)). That includes a string that looks constant but is built with `Sprintf` at package init.

## Back the rule with lint

The reviewer's trace is the enforcement; lint is a backstop. `gosec` G201 and G202 only check calls on `database/sql` `DB`, `Tx` and `Conn`, and skip operands that resolve to constants, so `Sprintf` over constants passes. They only match text with a `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `INTO`, `FROM` or `WHERE` keyword, so `SAVEPOINT`, `LOCK` and DDL never match. G201 also follows a query variable only when it is short-declared in the same function. A `forbidigo` rule can ban a repository's own SQL-building helpers.
