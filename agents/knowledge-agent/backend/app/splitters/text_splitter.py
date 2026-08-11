class TextSplitter:
    """
    Service-layer text splitter.

    Splits document text into overlapping chunks without database or AI calls.
    """

    def __init__(
        self,
        chunk_size: int = 1000,
        chunk_overlap: int = 200,
    ):
        if chunk_size <= 0:
            raise ValueError("chunk_size must be greater than 0")

        if chunk_overlap < 0:
            raise ValueError("chunk_overlap must be non-negative")

        if chunk_overlap >= chunk_size:
            raise ValueError("chunk_overlap must be less than chunk_size")

        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def split(self, text: str) -> list[dict]:
        if not text:
            return []

        if len(text) <= self.chunk_size:
            return [
                {
                    "content": text,
                    "chunk_index": 0,
                    "token_count": None,
                }
            ]

        chunks: list[dict] = []
        start = 0
        chunk_index = 0
        step = self.chunk_size - self.chunk_overlap

        while start < len(text):
            end = min(start + self.chunk_size, len(text))
            content = text[start:end]

            chunks.append(
                {
                    "content": content,
                    "chunk_index": chunk_index,
                    "token_count": None,
                }
            )

            if end >= len(text):
                break

            start += step
            chunk_index += 1

        return chunks
