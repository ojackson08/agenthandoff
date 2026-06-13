# Security Policy

## About This Project

`agenthandoff` is a **secure state-transfer protocol** for multi-agent AI systems, developed by Merkaba AI Risk Management. It handles the serialization and transfer of complete agent reasoning chains between agents. As a system that manages potentially sensitive agent state, its security is critical.

## Supported Versions

| Version | Supported |
|---|---|
| Current main | Yes |

## Reporting a Vulnerability

If you discover a security vulnerability in `agenthandoff` — including issues with state serialization that could expose sensitive reasoning data, SQS message tampering possibilities, IAM privilege escalation paths, or S3 access control misconfigurations — **please do not open a public GitHub issue.**

Report vulnerabilities directly to:

**Email:** security@merkabacreatives.org
**Subject line:** `[SECURITY] agenthandoff — <brief description>`

We will acknowledge receipt within **48 hours** and provide a remediation timeline within **5 business days**.

## Security Design Notes

- All handoff payloads are encrypted at rest in S3 using SSE-KMS.
- SQS messages contain only pointers and metadata — no raw reasoning chain data is transmitted via SQS.
- S3 object versioning is enabled to provide tamper evidence and rollback capability.
- IAM roles are scoped per-agent with least-privilege access to their own namespace only.
- All S3 and SQS operations are logged via CloudTrail.
- Dead-letter queues capture failed handoffs for forensic review.

## Responsible Disclosure

We follow coordinated disclosure. We ask that you give us reasonable time to investigate and patch before public disclosure.

## Contact

Merkaba AI Risk Management
security@merkabacreatives.org
https://merkabacreatives.org/ai-risk
