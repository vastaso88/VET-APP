from packages.core.application.ports.image_analyzer import ImageAnalyzer


class EchoImageAnalyzer(ImageAnalyzer):
    """Zero-cost demo/test double — mirrors EchoLLMClient's role: exercises
    the upload/analysis contract without a real Groq vision call or a
    real photo."""

    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        return f"[demo visual analysis of a {len(image_bytes)}-byte {content_type} image]"
