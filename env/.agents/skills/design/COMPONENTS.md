# Choosing a component

When to use each component. The rules follow the common practice of the major design systems (Material Design and Apple's Human Interface Guidelines agree on most of them).

## Choices

- **Radio buttons.** The user chooses exactly one option from a short list (about 2 to 6), and seeing all options helps the choice.
- **Segmented control.** The user switches between 2 to 5 views or modes of the same content. The change applies immediately.
- **Select (dropdown).** The user chooses one option from a long list, or the space is small. The options are hidden until the user opens the list, so prefer radio buttons for short lists.
- **Combobox (autocomplete).** A list too long to scan, where the user knows what to type, such as a country or a person.
- **Checkboxes.** The user chooses any number of options from a list.
- **Single checkbox.** One option that turns on or off when the user submits a form, or a confirmation such as "I agree".
- **Switch.** One setting that turns on or off and takes effect immediately, with no submit. Label it with the setting, not with an action.
- **Button group or chips.** Filters or tags that the user turns on and off, and that apply immediately to visible content.

## Input

- **Text input.** An answer of one line, such as a name. Use the matching type (`email`, `tel`, `number` for quantities only) so the right keyboard opens.
- **Textarea.** An answer longer than one line. Prefer a series of specific questions to one open question.
- **Slider.** An approximate value in a range, where the exact number matters less than the position (volume, brightness). Use a number input when the value must be exact.
- **Stepper.** A small whole number that changes by one, such as a quantity.
- **Date input.** A date the user knows, such as a date of birth: use separate fields or one text field with a clear format.
- **Date picker.** A date the user chooses relative to other dates, such as a booking.

## Actions

- **Button.** An action. Give each view one primary button. Label buttons with a verb that says what happens ("Save changes", not "OK").
- **Link.** Navigation to another place. Use a button for an action and a link for navigation, even when they look similar.
- **Icon button.** A frequent action with a well-known icon. Give it a tooltip and an accessible label.
- **Menu.** Secondary actions that do not fit, or that the user needs less often.

## Revealing content

- **Disclosure (details).** One section of extra content that only some users need.
- **Accordion.** Many sections where users open only the sections relevant to them. Content that all users need stays visible.
- **Tabs.** Parallel sections of one subject, where users need one section at a time. Use headings on one page when users must read the sections in order or compare them.
- **Modal dialog.** A decision that must happen before the user continues, or a short focused task. Prefer inline content for everything else, because a modal breaks the user's context.
- **Side panel (drawer).** Details or editing for an item while the user still sees the list or page behind it.
- **Popover.** Small, optional content tied to one element, such as a short form or extra details.
- **Tooltip.** A short label or hint for one control. Never put information that the user needs, or interactive content, in a tooltip.

## Feedback and messages

- **Inline validation message.** An error in one field, next to that field. Show it when the user leaves the field or submits, not while they type. For a long form, also list the errors at the top.
- **Toast (snackbar).** A short confirmation of an action the user just did, often with an undo. It disappears, so never put an error the user must act on in a toast.
- **Banner.** A message about the whole page or app (an outage, an expiring trial). Use banners sparingly, because users learn to ignore them.
- **Alert dialog.** Only for an action that the user cannot undo. Prefer undo to confirmation for everything else.
- **Empty state.** Every list or view that can be empty. Say why it is empty and give the action that fills it.
- **Skeleton or spinner.** A skeleton when the layout of the content is known. A spinner for short waits where it is not. A progress bar when the time is long and known.
- **Badge or tag.** A status or count on an item.

## Navigation and structure

- **Navigation bar or sidebar.** The top-level sections of the app. Keep the order and names the same on every page.
- **Breadcrumbs.** A deep hierarchy. A flat app or a linear flow has no use for them.
- **Stepper (wizard).** A linear task in a fixed order. Show the current step and the number of steps, and keep a way back.
- **Pagination.** Results where the user needs a stable position, or can jump to a page. **Infinite scroll** suits feeds the user browses with no goal. Use a "Load more" button when the page has a footer, or when keyboard users must reach content after the list.
- **Table.** Data that users compare across rows and columns. Use cards or a list when each item is read alone.
- **Key-value list.** The facts about one item, such as metadata or a summary before the user submits.
