<!-- Generated from docs/workflow-screens.md (sha256 da2793fb82c9) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflow-screens.md and run task generate. -->
# Workflow Screen Guidelines

The rules for the screens of a workflow's user tasks and for the documents it generates. The rules for the BPMN model
are in [workflow-modeling.md](~/.pyck/guidelines/docs/workflow-modeling.md), the rules for `Validate` in
[workflow-runs.md](~/.pyck/guidelines/docs/workflow-runs.md#keep-validate-pure-and-tie-every-submit-to-its-screen).

## Write every text for a logistician

Every text on a screen and on a document is written for the people in the warehouse: titles, hints, choices and error
messages. It names the order, the pallet, the slot and what to do next. It never shows an error code, a GraphQL message,
a stack trace, an id that nobody reads or a word such as "activity", "update" or "workflow". The technical cause goes to
the log.

## Show one physical step per screen

A screen asks for what one person does with their hands in one place: scan the pallet, count the pieces, put the label
on. A crowded screen means a split is missing.

## Ask for the minimum

"Everything is OK" is one tap. Fields for details appear only after the operator flags a deviation: a missing piece, a
damaged pallet, a wrong slot.

## Validate a scan on its screen

A bad scan shows an error on the same screen and asks again. It never moves the flow on. A check that needs the platform
runs after the submit, and the workflow awaits the same screen again with the reason, as in [Keep Validate
pure](~/.pyck/guidelines/docs/workflow-runs.md#keep-validate-pure-and-tie-every-submit-to-its-screen).

## Send a whole unit of work to the device

Send the device everything one unit of work needs, such as a whole pick list, and sync at natural pauses: the end of a
pallet, the end of a tour. A round trip per scan is slow on a warehouse network and costs API calls. Checks on the
screen are a convenience: the binding checks run in service tasks.

## Avoid the Remote Flutter Widget traps

- A `NumberInput` with a `max` changes a larger typed value to the maximum without a message (in UAT 120 was typed and
  40 booked). Show the error with `When` and refuse the value in `Validate` instead.
- The device sends 0 for a number the operator did not touch. Refuse it in `Validate` where 0 is not a real answer.
- Never name a context value like an input field. The two collide in the widget's data.
- A `ScanField` copies numbers as text. Parse the scan on purpose, and compare it with the context as text where leading
  zeros matter.

## Attach every generated document to its record

A label, a delivery note or a packing list that the workflow generates is attached to the record it belongs to: the
order, the pallet, the shipment. A reprint reads the attachment and never generates the document again. A second
generation can buy a second carrier label or draw a second number.

## Print once, and let the operator confirm it

A print job has no job id, so nobody can ask the printer whether it printed.

- Never retry a print after its first byte went out. Run it with one attempt, as in [Keep an outside call alone in its
  activity](~/.pyck/guidelines/docs/workflow-activities.md#keep-an-outside-call-alone-in-its-activity).
- "Printed" is the operator's confirmation on the screen after the print, not the result of the call.
- The screen offers a reprint of the attached document, so a jammed or lost print never needs the office.

## Mark a stand-in document so nobody mistakes it

When the real document cannot be generated, for example a carrier refuses the label, a stand-in may let the work go on.
A stand-in carries a large bold error text, such as "NOT A VALID LABEL: carrier refused", so that nobody can confuse it
with a real document. The run tells a person and offers the recovery path that replaces it with the real one.
