import base64
from typing import Any

from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.infrastructure.llm.providers.groq_chat_api import (
    GroqChatApi,
    Transport,
    split_models,
)
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

    def __init__(self, settings: Settings, *, transport: Transport | None = None) -> None:
        self._settings = settings
        self._api = GroqChatApi(
            base_url=settings.llm_base_url,
            api_key=settings.llm_api_key,
            timeout_seconds=settings.llm_timeout_seconds,
            models=[settings.vision_model, *split_models(settings.vision_fallback_models)],
            purpose="vision",
            transport=transport,
        )

    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        data_uri = f"data:{content_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"

        def payload(model: str) -> dict[str, Any]:
            return {
                "model": model,
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
                            "relevant, say so plainly rather than guessing. EXCEPTION — "
                            "if the image is a document (lab report, referto, "
                            "prescription, vaccination booklet): instead transcribe "
                            "its relevant content faithfully in Italian — document "
                            "type, date, the values/findings with their units and "
                            "reference ranges, and the written conclusions — as "
                            "compact text, up to about 10 lines. Copy what is written; "
                            "never interpret it, never add a value that is not "
                            "legible, and omit names of people, addresses and phone "
                            "numbers."
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
                "max_tokens": 700,
            }

        body, _model = self._api.complete(payload)

        choices = body.get("choices") or []
        if not choices:
            raise ProviderError("Groq vision response did not contain any choices")
        content = choices[0].get("message", {}).get("content")
        if not isinstance(content, str) or not content.strip():
            raise ProviderError("Groq vision response did not contain text")
        return content.strip()
