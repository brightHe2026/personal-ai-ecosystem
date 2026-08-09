from sqlalchemy.orm import Session

from app.services.document_service import DocumentService
from app.services.chunk_service import ChunkService
from app.services.embedding_service import EmbeddingService


class DocumentPipeline:
    """
    Knowledge-Agent 文档处理流水线

    流程:

    Document
        |
        v
    Chunk
        |
        v
    Embedding
        |
        v
    Vector Storage
    """


    def __init__(self):

        self.document_service = DocumentService()

        self.chunk_service = ChunkService()

        self.embedding_service = EmbeddingService()



    def process_document(
        self,
        db: Session,
        document_id: int
    ):
        """
        完整处理一个文档
        """


        # 1. 获取文档

        document = self.document_service.get_document(
            db,
            document_id
        )


        if not document:
            raise Exception(
                "Document not found"
            )


        # 2. 文档切片

        chunks = self.chunk_service.create_chunks(
            db,
            document
        )


        # 3. 生成 embedding

        texts = [
            chunk.content
            for chunk in chunks
        ]


        embeddings = (
            self.embedding_service
            .create_embeddings(texts)
        )


        # 4. 保存向量

        for chunk, embedding in zip(
            chunks,
            embeddings
        ):

            chunk.embedding = embedding


        db.commit()


        return chunks
