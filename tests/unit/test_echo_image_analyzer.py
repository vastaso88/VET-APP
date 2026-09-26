from packages.infrastructure.vision.echo_image_analyzer import EchoImageAnalyzer


def test_returns_a_demo_description_mentioning_size_and_type() -> None:
    analyzer = EchoImageAnalyzer()

    result = analyzer.analyze(b"0123456789", "image/jpeg", context="Specie: dog")

    assert "10-byte" in result
    assert "image/jpeg" in result
