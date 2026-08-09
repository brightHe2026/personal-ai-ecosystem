from typing import List

from app.providers.embedding.factory import (
    get_embedding_provider
)



class EmbeddingService:


    def __init__(self):

        self.provider = (
            get_embedding_provider()
        )



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
