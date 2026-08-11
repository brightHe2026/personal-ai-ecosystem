from typing import List

from app.providers.embedding.base import EmbeddingProvider
from app.providers.embedding.factory import get_embedding_provider


class EmbeddingService:
    """
    Business-facing embedding service.

    Depends only on EmbeddingProvider abstraction.
    Concrete vendors (e.g. OpenAI) are resolved via factory.
    """

    def __init__(self, provider: EmbeddingProvider | None = None):
        self.provider = provider or get_embedding_provider()



    def create_embedding(
        self,
        text: str
    ) -> List[float]:

        return (
            self.provider
            .embed(text)
        )



    def create_embeddings(
        self,
        texts: List[str]
    ) -> List[List[float]]:

        return (
            self.provider
            .embed_batch(texts)
        )
