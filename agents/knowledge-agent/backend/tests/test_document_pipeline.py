from unittest.mock import MagicMock, Mock, call

import pytest

from app.repositories.memory_vector_repository import MemoryVectorRepository
from app.services.document_pipeline import DocumentPipeline


def test_process_document_runs_splitter_chunk_embedding_vector_save_flow():
    """
    Document -> TextSplitter -> Chunk -> Embedding -> VectorRepository.save()
    """
    db = MagicMock()

    document_service = Mock()
    document_service.get_document.return_value = Mock(id=1)

    split_results = [
        {"content": "chunk one", "chunk_index": 0, "token_count": None},
        {"content": "chunk two", "chunk_index": 1, "token_count": None},
    ]

    text_splitter = Mock()
    text_splitter.split.return_value = split_results

    chunk_one = Mock(id=10, content="chunk one")
    chunk_two = Mock(id=11, content="chunk two")

    chunk_service = Mock()
    chunk_service.create_chunks.return_value = [chunk_one, chunk_two]

    embedding_service = Mock()
    embedding_service.create_embeddings.return_value = [
        [0.1, 0.2],
        [0.3, 0.4],
    ]

    vector_repository = Mock(spec=["save", "get", "search", "save_batch"])

    pipeline = DocumentPipeline(
        document_service=document_service,
        chunk_service=chunk_service,
        embedding_service=embedding_service,
        text_splitter=text_splitter,
        vector_repository=vector_repository,
    )

    result = pipeline.process_document(
        db,
        document_id=1,
        content="full document content",
    )

    document_service.get_document.assert_called_once_with(db, 1)
    text_splitter.split.assert_called_once_with("full document content")
    chunk_service.create_chunks.assert_called_once_with(db, 1, split_results)
    embedding_service.create_embeddings.assert_called_once_with(
        ["chunk one", "chunk two"]
    )
    assert vector_repository.save.call_args_list == [
        call(10, [0.1, 0.2]),
        call(11, [0.3, 0.4]),
    ]
    assert result == [chunk_one, chunk_two]


def test_process_document_persists_vectors_via_repository_interface():
    db = MagicMock()

    document_service = Mock()
    document_service.get_document.return_value = Mock(id=1)

    text_splitter = Mock()
    text_splitter.split.return_value = [
        {"content": "only chunk", "chunk_index": 0, "token_count": None},
    ]

    chunk = Mock(id=42, content="only chunk")
    chunk_service = Mock()
    chunk_service.create_chunks.return_value = [chunk]

    embedding_service = Mock()
    embedding_service.create_embeddings.return_value = [[0.7, 0.8]]

    # Inject via interface; concrete MVP used only as test double.
    vector_repository: MemoryVectorRepository = MemoryVectorRepository()

    pipeline = DocumentPipeline(
        document_service=document_service,
        chunk_service=chunk_service,
        embedding_service=embedding_service,
        text_splitter=text_splitter,
        vector_repository=vector_repository,
    )

    pipeline.process_document(db, document_id=1, content="only chunk")

    assert vector_repository.get(42) == [0.7, 0.8]
    assert vector_repository.search([0.7, 0.8], top_k=1)[0][0] == 42


def test_process_document_raises_when_document_missing():
    db = MagicMock()

    document_service = Mock()
    document_service.get_document.return_value = None

    pipeline = DocumentPipeline(
        document_service=document_service,
        chunk_service=Mock(),
        embedding_service=Mock(),
        text_splitter=Mock(),
        vector_repository=Mock(),
    )

    with pytest.raises(ValueError, match="Document not found"):
        pipeline.process_document(db, 1, "content")


def test_process_document_skips_embedding_and_vector_for_empty_content():
    db = MagicMock()

    document_service = Mock()
    document_service.get_document.return_value = Mock(id=1)

    text_splitter = Mock()
    text_splitter.split.return_value = []

    chunk_service = Mock()
    chunk_service.create_chunks.return_value = []

    embedding_service = Mock()
    vector_repository = Mock()

    pipeline = DocumentPipeline(
        document_service=document_service,
        chunk_service=chunk_service,
        embedding_service=embedding_service,
        text_splitter=text_splitter,
        vector_repository=vector_repository,
    )

    result = pipeline.process_document(db, 1, "")

    embedding_service.create_embeddings.assert_not_called()
    vector_repository.save.assert_not_called()
    assert result == []


def test_pipeline_module_does_not_import_concrete_memory_repository():
    import app.services.document_pipeline as pipeline_module

    assert not hasattr(pipeline_module, "MemoryVectorRepository")
    assert "MemoryVectorRepository" not in pipeline_module.__dict__
