from sqlalchemy import Column, Integer, String, JSON

from app.core.database import Base


class KnowledgeMetadata(Base):

    __tablename__ = "knowledge_metadata"


    id = Column(
        Integer,
        primary_key=True
    )


    document_id = Column(
        Integer
    )


    category = Column(
        String
    )


    tags = Column(
        JSON
    )


    extra = Column(
        JSON
    )
