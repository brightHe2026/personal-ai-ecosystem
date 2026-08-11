from math import sqrt
from typing import List, Sequence

from app.repositories.vector_repository import VectorRepository


class MemoryVectorRepository(VectorRepository):
    """
    TEST / MVP VectorRepository implementation.

    Stores embeddings in process memory only.
    Intended for unit tests and local Pipeline Core validation.

    NOT for production use.
    Replace later with a PostgreSQL + pgvector repository that
    implements the same VectorRepository interface.
    """

    def __init__(self):
        self._store: dict[int, List[float]] = {}

    def save(self, chunk_id: int, embedding: List[float]) -> None:
        self._store[chunk_id] = list(embedding)

    def save_batch(
        self,
        items: Sequence[tuple[int, List[float]]],
    ) -> None:
        for chunk_id, embedding in items:
            self.save(chunk_id, embedding)

    def get(self, chunk_id: int) -> List[float] | None:
        embedding = self._store.get(chunk_id)
        if embedding is None:
            return None
        return list(embedding)

    def search(
        self,
        query_embedding: List[float],
        top_k: int = 5,
    ) -> List[tuple[int, float]]:
        if top_k <= 0:
            return []

        if not query_embedding or not self._store:
            return []

        scored: list[tuple[int, float]] = []

        for chunk_id, embedding in self._store.items():
            score = self._cosine_similarity(query_embedding, embedding)
            scored.append((chunk_id, score))

        scored.sort(key=lambda item: item[1], reverse=True)
        return scored[:top_k]

    @staticmethod
    def _cosine_similarity(
        left: List[float],
        right: List[float],
    ) -> float:
        if len(left) != len(right):
            return 0.0

        dot = sum(a * b for a, b in zip(left, right))
        left_norm = sqrt(sum(a * a for a in left))
        right_norm = sqrt(sum(b * b for b in right))

        if left_norm == 0.0 or right_norm == 0.0:
            return 0.0

        return dot / (left_norm * right_norm)
