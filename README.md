# AgentHandoff: Stateful Cross-Agent Context Transfer Protocol

## The Gap in the Landscape
The #1 reason multi-agent systems fail is coordination loss. When Agent A finishes a task and hands off to Agent B, critical context—reasoning history, tool outputs, and intermediate decisions—often gets dropped or truncated due to context window limits. Current orchestration frameworks lack a durable, stateful "baton pass" mechanism.

## The Solution
**AgentHandoff** is an open-source, AWS-backed protocol that serializes an agent's full context state into a structured JSON envelope, stores it durably in S3, and delivers it to the next agent via SQS. It guarantees delivery, provides a full audit trail of inter-agent communication, and completely bypasses LLM context window limits during handoffs.

## Architecture
- **Amazon API Gateway:** Exposes a `/handoff` endpoint for agents to initiate a context transfer.
- **AWS Lambda (Python/Boto3):** Parses the handoff envelope, separates the heavy payload from the routing metadata.
- **Amazon S3:** Durably stores the heavy context payload (task history, decisions, raw data) as JSON.
- **Amazon SQS:** Queues the routing message containing the S3 URI, ensuring guaranteed delivery to the target agent even if it is currently busy.
- **Terraform:** Infrastructure as Code for 1-click deployment.

## Business Impact
Eliminates the "amnesia" problem in multi-agent swarms. Allows organizations to build complex, asynchronous agent workflows (e.g., Researcher Agent -> Coder Agent -> QA Agent) with 100% reliability and a complete forensic audit trail of what data was passed between agents.

## How to Deploy
```bash
cd terraform
terraform init
terraform apply
```

## Usage Example
Agent A sends its context to Agent B:
```json
{
  "source_agent": "Researcher-01",
  "target_agent": "Coder-02",
  "session_id": "req-9982",
  "context_payload": {
    "summary": "Found 3 API endpoints that need optimization.",
    "raw_data": [...],
    "reasoning_chain": [...]
  }
}
```
*Agent B polls SQS, receives the message, downloads the payload from S3, and begins work.*
