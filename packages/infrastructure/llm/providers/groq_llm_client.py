import json
from urllib import error, request

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError


class GroqLLMClient(LLMClient):
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def generate(self, req: LLMGenerationRequest) -> LLMResponse:
        payload = json.dumps(
            {
                "model": self._settings.llm_model,
                "messages": [
                    {"role": "system", "content": req.system_prompt},
                    {"role": "user", "content": req.user_prompt},
                ],
                "temperature": req.temperature,
                "max_tokens": req.max_tokens,
                # openai/gpt-oss-* models on Groq are reasoning models with no
                # cap on how much of max_tokens they spend on internal
                # chain-of-thought before writing the visible answer.
                # Confirmed live: at the default effort, a moderately
                # complex case consumed 1198 of a 1200-token budget on
                # reasoning alone, leaving nothing to write — empty content,
                # finish_reason "length", regardless of how high max_tokens
                # was raised. "low" keeps reasoning short enough that a
                # normal-length answer reliably still fits in the budget.
                # Verified against openai/gpt-oss-120b, the only model this
                # deployment configures — revisit if LLM_MODEL ever changes
                # to something that might reject an unrecognized field.
                "reasoning_effort": "low",
            }
        ).encode("utf-8")
        http_request = request.Request(
            url=f"{self._settings.llm_base_url.rstrip('/')}/chat/completions",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._settings.llm_api_key}",
                # Cloudflare (in front of Groq's API) blocks urllib's default
                # "Python-urllib/x.y" user agent outright (HTTP 403, error
                # code 1010) — any identifiable client string satisfies it.
                "User-Agent": "VetApp/1.0",
            },
            method="POST",
        )

        try:
            with request.urlopen(
                http_request, timeout=self._settings.llm_timeout_seconds
            ) as response:
                body = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            raise ProviderError(f"Groq request failed with status {exc.code}: {detail}") from exc
        except error.URLError as exc:
            raise ProviderError(f"Unable to reach Groq API: {exc.reason}") from exc
        except TimeoutError as exc:
            raise ProviderError("Groq request timed out") from exc

        choices = body.get("choices") or []
        if not choices:
            raise ProviderError("Groq response did not contain any choices")

        message = choices[0].get("message", {})
        usage = body.get("usage", {})
        return LLMResponse(
            content=message.get("content", "").strip(),
            provider=self._settings.llm_provider,
            model=body.get("model", self._settings.llm_model),
            token_count=int(usage.get("total_tokens", 0)),
            finish_reason=choices[0].get("finish_reason"),
        )
