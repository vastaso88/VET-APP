import base64
import json
from urllib import error, request

from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError


class GroqImageAnalyzer(ImageAnalyzer):
    """Visual analysis of an attached photo via a Groq multimodal model —
    a separate, focused call (mirrors SituationModelBuilder's own extra
    LLM call for text extraction), not the main chat model itself. The
    result is a plain-text description folded into the existing
    text-based pipeline (safety gate, evidence retrieval, synthesis all
    stay text-only) rather than making the whole chat orchestrator
    vision-aware.

    Model availability note: Groq's vision-capable model lineup changed
    more than once in 2026 (Llama 4 Maverick and Llama 4 Scout were both
    deprecated on the free/developer tier within months of release) —
    VISION_MODEL is a plain setting for exactly this reason. Verify the
    default against console.groq.com/docs/models before depending on it
    in production; this call fails closed (raises ProviderError) rather
    than silently degrading if the configured model is rejected.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        data_uri = f"data:{content_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"
        payload = json.dumps(
            {
                "model": self._settings.vision_model,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You are a veterinary assistant analyzing a photo an owner "
                            "attached to a chat about their pet. Describe only what is "
                            "visually observable that could be clinically or "
                            "husbandry-relevant (skin/coat condition, wounds, swelling, "
                            "posture, discharge, visible behavior, enclosure/habitat "
                            "details). Never name or suggest a diagnosis — describe "
                            "observations only, in Italian, in 2-4 short sentences. If "
                            "the image is unclear, blurry, or shows nothing clinically "
                            "relevant, say so plainly rather than guessing."
                        ),
                    },
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": context or "Descrivi questa immagine."},
                            {"type": "image_url", "image_url": {"url": data_uri}},
                        ],
                    },
                ],
                "temperature": 0.2,
                "max_tokens": 400,
            }
        ).encode("utf-8")

        http_request = request.Request(
            url=f"{self._settings.llm_base_url.rstrip('/')}/chat/completions",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._settings.llm_api_key}",
                # See GroqLLMClient for why: Cloudflare blocks urllib's
                # default user agent outright.
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
            raise ProviderError(
                f"Groq vision request failed with status {exc.code}: {detail}"
            ) from exc
        except error.URLError as exc:
            raise ProviderError(f"Unable to reach Groq API: {exc.reason}") from exc
        except TimeoutError as exc:
            raise ProviderError("Groq vision request timed out") from exc

        choices = body.get("choices") or []
        if not choices:
            raise ProviderError("Groq vision response did not contain any choices")
        content = choices[0].get("message", {}).get("content")
        if not isinstance(content, str) or not content.strip():
            raise ProviderError("Groq vision response did not contain text")
        return content.strip()
