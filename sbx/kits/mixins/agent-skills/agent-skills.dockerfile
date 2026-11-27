# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# The overlay for the agent-skills mixin: the skills that sync-skills copies
# into skills/. agent-skills.yaml, which sync-skills also writes, declares one
# agent-skill@1 entry for each.
FROM scratch
COPY skills/ /usr/share/agent-skills/
