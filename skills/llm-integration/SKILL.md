---
name: llm-integration
description: Add reliable LLM calls to a Python backend - one injected client, structured output validated with Pydantic, business-rule checks, timeouts and bounded retries, a shared rate limiter, batching, versioned prompts, cost limits, and caching. Use when adding or reviewing code that calls a large language model.
---

# LLM Integration

An **LLM call** sends a prompt to a large language model and gets an answer back. The model can be slow, rate-limited, expensive, and sometimes wrong. These rules keep those problems in one place and stop bad answers from reaching your data.

The examples use one feature: read a product review and extract a `rating` from 1 to 5 and a one-line `summary`.

## 1. One Client, Created Once

Create one LLM client at startup and inject it where it is needed, the same way the project injects its database session. Never create a client inside a function or keep it in a module-level variable.

The client is the only place that holds the timeout, retries, rate limit, credentials, and call logging. Services call your client; they never call the provider's SDK directly.

## 2. Ask for Structured Output

Use the provider's structured-output (or tool-calling) mode and give it a Pydantic model as the schema. Never pull values out of free text with regex.

```python
class ReviewAnalysis(BaseModel):
    rating: int
    summary: str
```

## 3. Validate Against Business Rules

A schema checks types, not meaning. Put the business rules on the model too:

```python
class ReviewAnalysis(BaseModel):
    rating: int = Field(ge=1, le=5)
    summary: str = Field(max_length=200)
```

Invalid output is never stored and never replaced with a default.

- Bad: the model returns `rating: 7` and the code stores `5` (clamped) or `0` (a default). The data now looks valid but is wrong.
- Good: validation fails, so retry once with the validation error added to the prompt. If it fails again, mark the review `analysis_failed` for a person to check.

## 4. Timeouts and Retries

- Every call has a timeout.
- Retry only temporary failures: rate limits (429), server errors (5xx), and timeouts. Never retry a rejected request (400).
- Make at most 3 attempts, waiting longer each time (exponential backoff, for example 1, 2, then 4 seconds).
- Retry the one call that failed, not the whole batch.

## 5. One Shared Rate Limiter

Providers limit requests and tokens per minute. Use one rate limiter per provider, shared by every code path that calls it. Inside one process it lives in the client; with several processes or workers, keep its counter in a shared store such as Redis.

## 6. Batch Independent Items

When items do not depend on each other, send several in one call and size the batch by token count, not item count. Call one item at a time only when each step needs the previous answer.

## 7. Version Your Prompts

Keep each prompt in a file named by purpose and version, such as `prompts/review_analysis/v2.md`. Load prompts by name and version, and log the version with every call, so you can tell which prompt produced which result.

## 8. Cap the Cost of a Request

Set limits per request: maximum calls, tokens, and seconds. When a limit is reached, stop and return the results so far with a clear status such as `budget_exhausted`, instead of running without limit.

## 9. Cache Repeated Calls

Cache results by a hash of the prompt version, the model parameters, and the input, and give each entry an expiry time (TTL). The prompt version must be part of the key, so a new prompt never returns old answers.

```python
key_data = {"prompt": "review_analysis/v2", "params": params, "input": review_text}
key = hashlib.sha256(json.dumps(key_data, sort_keys=True).encode()).hexdigest()
```
