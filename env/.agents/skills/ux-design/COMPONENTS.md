# Choosing a component

When to use each component, adapted from the GOV.UK Design System. GOV.UK designs for every member of the public, so its rules are strict. For a product that experts use often, tabs and accordions are acceptable more often.

## Choices

- **Radios.** The user can choose only one option from a short list.
- **Checkboxes.** The user can choose more than one option from a list. A single checkbox turns one option on or off, and the change applies when the user submits the form.
- **Switch.** GOV.UK has no switch. Use a switch for one setting that turns on or off and takes effect immediately, with no submit. Inside a form that the user submits, use a single checkbox.
- **Select.** Use a select only as a last resort, because many users find selects difficult. First, ask questions that reduce the options, so that radios are enough.

## Text and dates

- **Text input.** An answer of one line, such as a name or a phone number.
- **Textarea.** An answer longer than one line. Open questions are difficult to answer, so prefer a series of simple questions with radios.
- **Character count.** Use one only when there is a real reason to limit the length (legal, technical, or evidence that users write too much). If users often reach a back-end limit, increase the limit.
- **Date input.** A date that the user knows or can find without a calendar, such as a date of birth. If the user must choose a date relative to other dates, use a date picker.
- **Fieldset.** Groups related inputs under one legend, such as the parts of an address.

## Revealing content

- **Details.** One section of content that only some users need. It is less prominent than tabs or an accordion.
- **Tabs.** Clearly labeled sections where the first section is the most relevant, and users do not need to see all sections at once. Use headings on one page when users must read the sections in order or compare them.
- **Accordion.** An overview of many related sections, from which users open the ones relevant to them. Before you add one, try simpler content: less of it, headings on one page, or more pages. Content that all users need stays visible.

## Messages

- **Error message.** Next to the field that has a validation error. Also show an **error summary** at the top of the page, even for one error. When the problem is with the service and not the user's input (no permission, not eligible, service down), go to a page that explains it and says what to do next.
- **Inset text.** Sets apart a quote, an example, or extra information. Users can miss it, so use warning text for important information.
- **Warning text.** Important consequences, such as legal consequences of an action.
- **Notification banner.** Information that is not about the current task (a service-wide problem, a deadline, or the result of the previous action). Use it sparingly, because users miss banners. Validation errors use the error components instead.
- **Panel.** Only on a confirmation page (the task is complete) or an interruption page.
- **Tag.** The status of an item that can have more than one status, such as "Completed" in a task list.

## Navigation and structure

- **Button.** An action, such as start, save, or continue. To move between steps of a form, use a "Continue" button and a back link.
- **Back link.** Pages in a multi-step journey. Use a back link or breadcrumbs, not both.
- **Breadcrumbs.** Moving between levels of a site with a deep hierarchy. A flat site or a linear journey has no use for them.
- **Pagination.** Content too long to load on one page, when most users need only the first pages. Use pagination instead of infinite scroll, which fails for keyboard users.
- **Task list.** A long service that users complete over several sessions, in an order they choose. If the order is fixed, use steps and let users save their progress. First, try to reduce the number of tasks.
- **Summary list.** Key-value facts, such as metadata or the answers on a "check your answers" page.
- **Table.** Data that users compare in rows and columns. Use the layout grid for page layout.
