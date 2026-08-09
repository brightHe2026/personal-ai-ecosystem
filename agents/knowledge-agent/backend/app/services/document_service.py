from sqlalchemy.orm import Session

from app.models.document import Document


class DocumentService:

    def create_document(
        self,
        db: Session,
        title: str,
        source_type: str,
        file_path: str,
        content_hash: str | None = None,
    ):

        document = Document(
            title=title,
            source_type=source_type,
            file_path=file_path,
            content_hash=content_hash,
        )

        db.add(document)
        db.commit()
        db.refresh(document)

        return document


    def get_document(
        self,
        db: Session,
        document_id: int,
    ):

        return (
            db.query(Document)
            .filter(Document.id == document_id)
            .first()
        )


    def list_documents(
        self,
        db: Session,
    ):

        return (
            db.query(Document)
            .order_by(Document.created_at.desc())
            .all()
        )


document_service = DocumentService()
