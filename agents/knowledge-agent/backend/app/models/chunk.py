from sqlalchemy import Column, Integer, String, Text, ForeignKey

from app.core.database import Base

from pgvector.sqlalchemy import Vector

class Chunk(Base):

    __tablename__ = "chunks"


    id = Column(
        Integer,
        primary_key=True
    )


    document_id = Column(
        Integer,
        ForeignKey("documents.id")
    )


    content = Column(
        Text
    )


    chunk_index = Column(
        Integer
    )


    token_count = Column(
        Integer
    )

    embedding = Column(
        Vector(1536)
    )
