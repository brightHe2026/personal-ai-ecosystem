from app.repositories.memory_vector_repository import MemoryVectorRepository
from app.repositories.vector_repository import VectorRepository


def get_vector_repository() -> VectorRepository:
    """
    Resolve the active VectorRepository implementation.

    MVP default: MemoryVectorRepository (test / local only).
    Future: swap to PostgreSQL + pgvector without changing callers.
    """
    return MemoryVectorRepository()
