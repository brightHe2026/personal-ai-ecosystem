from typing import List

from openai import OpenAI

from app.providers.embedding.base import EmbeddingProvider



class OpenAIEmbeddingProvider(
    EmbeddingProvider
):


    def __init__(
        self,
        api_key: str,
        model: str = "text-embedding-3-small"
    ):

        self.client = OpenAI(
            api_key=api_key
        )

        self.model = model



    def embed(
        self,
        text: str
    ) -> List[float]:


        response = (
            self.client
            .embeddings
            .create(
                model=self.model,
                input=text
            )
        )


        return (
            response
            .data[0]
            .embedding
        )



    def embed_batch(
        self,
        texts: List[str]
    ) -> List[List[float]]:


        response = (
            self.client
            .embeddings
            .create(
                model=self.model,
                input=texts
            )
        )


        return [
            item.embedding
            for item in response.data
        ]
