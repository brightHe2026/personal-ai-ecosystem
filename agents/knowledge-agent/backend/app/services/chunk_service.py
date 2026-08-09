from sqlalchemy.orm import Session

from app.models.chunk import Chunk

from app.services.embedding_service import EmbeddingService

class ChunkService:

    def __init__(self):

        self.embedding_service = EmbeddingService()

    def create_chunk(
        self,
        db: Session,
        document_id: int,
        content: str,
        chunk_index: int,
        token_count: int | None = None,
    ):

        embedding = (
            self.embedding_service
            .create_embedding(content)
        )



        chunk = Chunk(
            document_id=document_id,
            content=content,
            chunk_index=chunk_index,
            token_count=token_count,
        )

        db.add(chunk)
        db.commit()
        db.refresh(chunk)

        return chunk



    def create_chunks(
        self,
        db: Session,
        document_id: int,
        chunks: list[dict],
    ):

        objects = []

        for item in chunks:

            chunk = Chunk(
                document_id=document_id,
                content=item["content"],
                chunk_index=item["chunk_index"],
                token_count=item.get("token_count"),
            )

            objects.append(chunk)


        db.add_all(objects)
        db.commit()


        for obj in objects:
            db.refresh(obj)


        return objects



    def get_document_chunks(
        self,
        db: Session,
        document_id: int,
    ):

        return (
            db.query(Chunk)
            .filter(
                Chunk.document_id == document_id
            )
            .order_by(
                Chunk.chunk_index
            )
            .all()
        )



chunk_service = ChunkService()
