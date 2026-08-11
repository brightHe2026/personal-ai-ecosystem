from unittest.mock import Mock

from app.services.embedding_service import EmbeddingService


def test_create_embedding_delegates_to_provider():
    provider = Mock()
    provider.embed.return_value = [0.1, 0.2, 0.3]

    service = EmbeddingService(provider=provider)

    result = service.create_embedding("hello")

    provider.embed.assert_called_once_with("hello")
    assert result == [0.1, 0.2, 0.3]


def test_create_embeddings_delegates_to_provider_batch():
    provider = Mock()
    provider.embed_batch.return_value = [[1.0], [2.0]]

    service = EmbeddingService(provider=provider)

    result = service.create_embeddings(["a", "b"])

    provider.embed_batch.assert_called_once_with(["a", "b"])
    assert result == [[1.0], [2.0]]
