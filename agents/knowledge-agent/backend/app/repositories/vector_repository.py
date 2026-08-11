from abc import ABC, abstractmethod
from typing import List, Sequence


class VectorRepository(ABC):
    """
    Abstract vector persistence and retrieval interface.

    Layering:

        Service / Pipeline
            |
            v
        VectorRepository (interface)
            |
            v
        Concrete Repository

    Concrete backends (Memory MVP now, PostgreSQL + pgvector later)
    must be swappable without changing Pipeline / Service code.
    """

    @abstractmethod
    def save(self, chunk_id: int, embedding: List[float]) -> None:
        """Persist a single chunk embedding."""

    @abstractmethod
    def save_batch(
        self,
        items: Sequence[tuple[int, List[float]]],
    ) -> None:
        """Persist multiple chunk embeddings."""

    @abstractmethod
    def get(self, chunk_id: int) -> List[float] | None:
        """Return stored embedding for a chunk, or None."""

    @abstractmethod
    def search(
        self,
        query_embedding: List[float],
        top_k: int = 5,
    ) -> List[tuple[int, float]]:
        """
        Similarity search.

        Returns:
            List of (chunk_id, score) ordered by descending score.
        """
