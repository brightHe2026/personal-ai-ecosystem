from app.repositories.memory_vector_repository import MemoryVectorRepository


def test_save_and_get_embedding():
    repo = MemoryVectorRepository()

    repo.save(1, [0.1, 0.2, 0.3])

    assert repo.get(1) == [0.1, 0.2, 0.3]


def test_get_missing_chunk_returns_none():
    repo = MemoryVectorRepository()

    assert repo.get(999) is None


def test_save_batch_persists_all_embeddings():
    repo = MemoryVectorRepository()

    repo.save_batch(
        [
            (10, [1.0, 0.0]),
            (11, [0.0, 1.0]),
        ]
    )

    assert repo.get(10) == [1.0, 0.0]
    assert repo.get(11) == [0.0, 1.0]


def test_save_overwrites_existing_embedding():
    repo = MemoryVectorRepository()

    repo.save(1, [0.1])
    repo.save(1, [0.9])

    assert repo.get(1) == [0.9]


def test_get_returns_copy_not_internal_reference():
    repo = MemoryVectorRepository()
    original = [0.5, 0.6]

    repo.save(1, original)
    stored = repo.get(1)
    stored[0] = 9.9

    assert repo.get(1) == [0.5, 0.6]


def test_search_returns_top_k_by_cosine_similarity():
    repo = MemoryVectorRepository()

    repo.save(1, [1.0, 0.0])
    repo.save(2, [0.0, 1.0])
    repo.save(3, [0.8, 0.2])

    results = repo.search([1.0, 0.0], top_k=2)

    assert len(results) == 2
    assert results[0][0] == 1
    assert results[0][1] == 1.0
    assert results[1][0] == 3
    assert results[1][1] > 0.0


def test_search_empty_store_returns_empty_list():
    repo = MemoryVectorRepository()

    assert repo.search([1.0, 0.0], top_k=3) == []
