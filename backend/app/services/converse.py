"""
Model-neutral Bedrock calls via the Converse API.

One request/response shape for every text model (Amazon Nova, Qwen, Mistral, ...),
so the model is a setting, not code. Pure helpers: no AWS calls here.
"""


def build_request(
    model_id: str,
    prompt: str,
    max_tokens: int = 1024,
    temperature: float = 0.1,
    guardrail_id: str = "",
    guardrail_version: str = "",
) -> dict:
    """Keyword arguments for bedrock-runtime `converse`."""
    request = {
        "modelId": model_id,
        "messages": [{"role": "user", "content": [{"text": prompt}]}],
        "inferenceConfig": {"maxTokens": max_tokens, "temperature": temperature},
    }
    if guardrail_id and guardrail_version:
        request["guardrailConfig"] = {
            "guardrailIdentifier": guardrail_id,
            "guardrailVersion": guardrail_version,
        }
    return request


def extract_text(response: dict) -> str:
    """The model's text from a converse response.

    Reasoning models add non-text blocks (reasoningContent); only text counts.
    Raises ValueError when there is none, e.g. the guardrail blocked the reply or
    the token budget was spent thinking."""
    try:
        blocks = response["output"]["message"]["content"]
    except (KeyError, TypeError):
        raise ValueError("Unexpected response from the model")
    text = "".join(b["text"] for b in blocks if isinstance(b, dict) and isinstance(b.get("text"), str)).strip()
    if not text:
        reason = response.get("stopReason", "unknown")
        raise ValueError(f"The model returned no text (stop reason: {reason})")
    return text
