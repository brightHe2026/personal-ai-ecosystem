import os

from dotenv import load_dotenv

from app.providers.embedding.openai_provider import (
    OpenAIEmbeddingProvider
)


load_dotenv()

def get_embedding_provider():


    provider = os.getenv(
        "EMBEDDING_PROVIDER",
        "openai"
    )


    if provider == "openai":

        return OpenAIEmbeddingProvider(
            api_key=os.getenv(
                "OPENAI_API_KEY"
            )
        )


    raise ValueError(
        f"Unsupported provider: {provider}"
    )
