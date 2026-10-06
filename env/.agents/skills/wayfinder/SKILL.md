---
name: wayfinder
description: Plan an effort too big for one agent session as a shared map of decision tickets on the project's tracker, and resolve the tickets one at a time until the way is clear.
disable-model-invocation: true
---

A loose idea is too big for one session, and fog hides the way from here to the **destination**. This skill charts the way as a **map** on the tracker, then resolves its **decision tickets** one at a time until the route is clear. A decision ticket is a question whose answer is a decision, not a slice of a build.

The destination can be a spec to hand off, a decision to lock before planning, or a change made in place, such as a data migration. The map works for any domain, not only code.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill. Its "Maps" section tells you where the map and its tickets live, and how to block, find the frontier, claim, and resolve.

## Plan, don't do

The map produces decisions, not deliverables. It is done when nothing is left to decide before someone does the work. When you feel the pull to do the work, you are probably at the edge of the map, and it is time to hand off. The map's **Notes** can override this for one effort.

In everything the human reads, refer to a map or ticket by its title, with its link inside the title. A list of bare numbers is illegible.

## The map

The map is an **index**, not a store. Each decision lives in its ticket only; the map gives a one-line gist and a link. Open tickets are not listed: they are found by the frontier query.

```markdown
## Destination

<one or two lines: the spec, decision, or change that this effort finds its way to>

## Notes

<the domain, the skills every session uses, and the standing preferences for this effort>

## Decisions so far

- [<closed ticket title>](link): <one-line gist of the answer>

## Not yet specified

<the fog: in-scope questions you cannot state sharply yet>

## Out of scope

- [<closed ticket title>](link): <gist, and why it is out of scope>
```

## Tickets

A ticket body is one question, sized to one session of about 100K tokens:

```markdown
## Question

<the decision or investigation that this ticket resolves>
```

The tracker records the answer on resolution. Link assets that the work creates from the ticket; do not paste them in. A ticket has one type. An **AFK** ticket is yours alone. A **HITL** ticket resolves only in a live exchange with the human, who speaks for themselves: you ask, and you wait for their answer. An agent that answers its own grilling questions has broken the ticket.

- **research** (AFK): find a fact outside the repo that a decision waits on. Resolve it with the `research` skill, and link the findings file from the ticket.
- **prototype** (HITL): make a cheap, concrete artifact to react to, with the `author-prototype` skill. Use it when "how should it look" or "how should it behave" is the key question.
- **grilling** (HITL): a conversation, with the `grilling` and `domain-modeling` skills. This is the default.
- **task** (AFK or HITL): work that must happen before a decision can be made (sign up for a service, get access, move data). It is the one type that does instead of decides, and it unblocks a decision; it never delivers the destination. Do it yourself where you can; otherwise give the human a precise checklist. The answer records what was done and the facts later tickets need (where the credentials are, new URLs, row counts).

## Fog of war

The map is incomplete on purpose. The test for a ticket is whether you can state the question sharply now, not whether you can answer it now. Ticket a sharp question, even if it is blocked. Write a dim one loosely under **Not yet specified**, and do not slice it into ticket-sized pieces: one patch of fog can become several tickets, or none. Each resolution clears fog ahead of it. **Not yet specified** holds only fog: what is decided, ticketed, or out of scope goes in its own place.

Work past the destination is **out of scope**, not fog, and it never graduates. If a ticket turns out to sit past the destination, close it and add it to **Out of scope**. It stays out of **Decisions so far**, which records only the route walked. Out-of-scope work comes back only if the destination is redrawn, and then as a new effort.

## Chart the map

The user gives a loose idea.

1. **Name the destination** with the `grilling` and `domain-modeling` skills. It fixes the scope and shapes every ticket, so settle it first.
2. **Map the frontier**: grill again, breadth-first across the whole space, for the open decisions and the first steps you can take now. If this finds no fog, the effort fits in one session and needs no map: stop and ask the user how to continue.
3. **Create the map** with Destination, Notes, and Not yet specified filled in.
4. **Create the tickets** you can state now, then add the blocking edges in a second pass, because a ticket needs an identifier before another can refer to it.
5. **Resolve every research ticket** with the `research` skill.
6. Stop. Charting resolves no other ticket.

## Work through the map

The user gives a map, and optionally a ticket. Resolve one ticket per session; research tickets are the only exception.

1. Load the map, but not every ticket body.
2. Take the ticket the user named, or else the first frontier ticket. Claim it before any other work, so that concurrent sessions skip it.
3. Resolve it. Fetch any related or closed ticket when you need its detail. Use the skills that the map's Notes name; if in doubt, use the `grilling` and `domain-modeling` skills.
4. Record the resolution the way `docs/agents/issue-tracker.md` describes, with a line in **Decisions so far**.
5. Create the new tickets that the answer reveals, and wire their edges. Move fog that the answer made sharp out of **Not yet specified** and into tickets. Rule out of scope any ticket that the answer puts past the destination. Update or delete the tickets that the answer invalidates.

Other sessions can work unblocked tickets at the same time, so expect the tracker to change under you.
