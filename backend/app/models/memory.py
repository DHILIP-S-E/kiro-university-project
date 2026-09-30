import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class MemoryDocument(Base):
    __tablename__ = "memory_documents"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    event_id: Mapped[str | None] = mapped_column(String(36), index=True)
    event_title: Mapped[str | None] = mapped_column(String(500))
    overview: Mapped[str | None] = mapped_column(Text)
    key_topics: Mapped[str | None] = mapped_column(Text)        # JSON array
    key_takeaways: Mapped[str | None] = mapped_column(Text)     # JSON array
    things_learned: Mapped[str | None] = mapped_column(Text)    # JSON array
    important_people: Mapped[str | None] = mapped_column(Text)  # JSON array
    resources: Mapped[str | None] = mapped_column(Text)         # JSON array
    links: Mapped[str | None] = mapped_column(Text)             # JSON array
    action_items: Mapped[str | None] = mapped_column(Text)      # JSON array
    deadlines: Mapped[str | None] = mapped_column(Text)         # JSON array
    decisions: Mapped[str | None] = mapped_column(Text)         # JSON array
    # Concatenated text for full-text keyword search (updated on save)
    search_vector: Mapped[str | None] = mapped_column(Text)
    event_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow
    )

    def to_dict(self) -> dict:
        import json

        def _load(val):
            return json.loads(val) if val else []

        return {
            "id": self.id,
            "user_id": self.user_id,
            "event_id": self.event_id,
            "event_title": self.event_title,
            "overview": self.overview,
            "key_topics": _load(self.key_topics),
            "key_takeaways": _load(self.key_takeaways),
            "things_learned": _load(self.things_learned),
            "important_people": _load(self.important_people),
            "resources": _load(self.resources),
            "links": _load(self.links),
            "action_items": _load(self.action_items),
            "deadlines": _load(self.deadlines),
            "decisions": _load(self.decisions),
            "event_date": self.event_date.isoformat(),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }
