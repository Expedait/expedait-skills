# Security Policy

## Scope

This repository contains **documentation-only** agent skills — Markdown `SKILL.md` files
and the `build.py` generator. The skills instruct AI agents to invoke the separate
`expedait-cli` tool and the hosted Expedait MCP server (`https://mcp.expedait.org`);
this repo ships no runtime service and stores no credentials.

Report vulnerabilities in the CLI, the API, or the MCP server against their own
projects. Use this policy for issues in the skills themselves — for example, a skill that
would lead an agent to leak credentials, run a destructive command, or exfiltrate data.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security problems.**

- Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  (the **Report a vulnerability** button under this repo's **Security** tab), or
- Email **support@expedait.org** with a description, reproduction steps, and impact.

We aim to acknowledge reports within 3 business days and to provide a remediation
timeline after triage. Please give us a reasonable window to address the issue before
any public disclosure.

## Handling credentials safely

The Expedait CLI caches credentials in `~/.expedait/config.json` and reads
`EXPEDAIT_TOKEN` / `EXPEDAIT_API_URL` / `EXPEDAIT_TENANT_ID` from the environment. Never
commit these files or values, and never paste tokens into issues, pull requests, or
skill content.
