from sqlalchemy.orm import Session

from app.repositories.factory import get_vector_repository
from app.repositories.vector_repository import VectorRepository
from app.splitters.text_splitter import TextSplitter
from app.services.document_service import DocumentService
from app.services.chunk_service import ChunkService
from app.services.embedding_service import EmbeddingService


class DocumentPipeline:
    """
    Knowledge-Agent document processing pipeline.

    Flow:

    Document
        |
        v
    TextSplitter
        |
        v
    ChunkService
        |
        v
    EmbeddingService (via EmbeddingProvider)
        |
        v
    VectorRepository.save()
    """

    def __init__(
        self,
        document_service: DocumentService | None = None,
        chunk_service: ChunkService | None = None,
        embedding_service: EmbeddingService | None = None,
        text_splitter: TextSplitter | None = None,
        vector_repository: VectorRepository | None = None,
    ):
        self.document_service = document_service or DocumentService()
        self.chunk_service = chunk_service or ChunkService()
        self.embedding_service = embedding_service or EmbeddingService()
        self.text_splitter = text_splitter or TextSplitter()
        # Depend on VectorRepository interface only.
        # Concrete backend is resolved via factory when not injected.
        self.vector_repository = (
            vector_repository or get_vector_repository()
        )

    def process_document(
        self,
        db: Session,
        document_id: int,
        content: str,
    ):
        document = self.document_service.get_document(
            db,
            document_id,
        )

        if not document:
            raise ValueError("Document not found")

        split_results = self.text_splitter.split(content)

        chunks = self.chunk_service.create_chunks(
            db,
            document_id,
            split_results,
        )

        if not chunks:
            return chunks

        texts = [chunk.content for chunk in chunks]

        embeddings = self.embedding_service.create_embeddings(texts)

        for chunk, embedding in zip(chunks, embeddings):
            self.vector_repository.save(chunk.id, embedding)

        return chunks
