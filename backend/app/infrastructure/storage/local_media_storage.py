from __future__ import annotations

import base64
import mimetypes
import shutil
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from uuid import uuid4

from fastapi import UploadFile

from app.core.config import Settings

_PLACEHOLDER_JPEG_BASE64 = (
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBxAQEBUQEBAVFRUVFRUVFRUVFRUVFRUVFRUWFhUVFRUY"
    "HSggGBolGxUVITEhJSkrLi4uFx8zODMsNygtLisBCgoKDg0OGhAQGy0lICUtLS8tLS0tLS0tLS0tLS0t"
    "LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLf/AABEIAAEAAgMBIgACEQEDEQH/xAAXAAEBAQEA"
    "AAAAAAAAAAAAAAAAAQID/8QAFhEBAQEAAAAAAAAAAAAAAAAAABEB/9oADAMBAAIQAxAAAAHJgP/EABgQ"
    "AQEBAQEAAAAAAAAAAAAAAAERACEx/9oACAEBAAEFAkTnH//EABYRAQEBAAAAAAAAAAAAAAAAAAARIf/a"
    "AAgBAwEBPwGn/8QAFhEBAQEAAAAAAAAAAAAAAAAAABEh/9oACAECAQE/AY//xAAaEAADAQEBAQAAAAAA"
    "AAAAAAAREhMUFR/9oACAEBAAY/AtGmG0f/xAAaEAACAwEBAAAAAAAAAAAAAAAAAREhMUFh/9oACAEBAA"
    "E/IdY1i5F2Rp6g4//aAAwDAQACAAMAAAAQ8//EABcRAAMBAAAAAAAAAAAAAAAAAAABESH/2gAIAQMBAT"
    "8QdKf/xAAXEQADAQAAAAAAAAAAAAAAAAAAAREx/9oACAECAQE/EHmu/8QAGhABAQACAwAAAAAAAAAAAA"
    "AAAREAITFBYf/aAAgBAQABPxBQF1Tmi2HnGK1Jd4z/2Q=="
)
_DEMO_FILE_PATHS = (
    "demo/palm-suite-cover.jpg",
    "demo/sky-loft-cover.jpg",
    "demo/garden-room-cover.jpg",
    "demo/sun-deck-cover.jpg",
)


@dataclass(frozen=True)
class StoredMediaFile:
    relative_path: str
    original_filename: str | None
    content_type: str | None
    size_bytes: int


class LocalMediaStorage:
    def __init__(self, settings: Settings):
        self._settings = settings
        self._root = Path(settings.media_root).expanduser()

    def ensure_ready(self) -> None:
        self._root.mkdir(parents=True, exist_ok=True)

    def ensure_demo_assets(self) -> None:
        self.ensure_ready()
        placeholder_bytes = base64.b64decode(_PLACEHOLDER_JPEG_BASE64)
        for relative_path in _DEMO_FILE_PATHS:
            target = self.absolute_path(relative_path)
            if target.exists():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(placeholder_bytes)

    def save_upload(
        self, *, namespace: str, owner_id: str, upload_file: UploadFile
    ) -> StoredMediaFile:
        self.ensure_ready()
        original_filename = upload_file.filename or "upload"
        suffix = (
            Path(original_filename).suffix.lower()
            or mimetypes.guess_extension(upload_file.content_type or "")
            or ""
        )
        relative_path = str(PurePosixPath(namespace) / owner_id / f"{uuid4().hex}{suffix}")
        destination = self.absolute_path(relative_path)
        destination.parent.mkdir(parents=True, exist_ok=True)

        with destination.open("wb") as handle:
            shutil.copyfileobj(upload_file.file, handle)

        upload_file.file.close()
        return StoredMediaFile(
            relative_path=relative_path,
            original_filename=original_filename,
            content_type=upload_file.content_type,
            size_bytes=destination.stat().st_size,
        )

    def delete_file(self, relative_path: str | None) -> None:
        if not relative_path:
            return
        destination = self.absolute_path(relative_path)
        if destination.exists() and destination.is_file():
            destination.unlink()
        self._prune_empty_directories(destination.parent)

    def public_url(self, relative_path: str | None) -> str | None:
        if not relative_path:
            return None
        normalized = self.normalize_relative_path(relative_path)
        return f"{self._settings.normalized_media_public_base_url}/{normalized}"

    def absolute_path(self, relative_path: str) -> Path:
        normalized = self.normalize_relative_path(relative_path)
        return self._root.joinpath(*PurePosixPath(normalized).parts)

    def normalize_relative_path(self, relative_path: str) -> str:
        cleaned = str(PurePosixPath(relative_path.strip("/")))
        parts = PurePosixPath(cleaned).parts
        if not cleaned or any(part in {".", ".."} for part in parts):
            raise ValueError("Invalid relative media path")
        return cleaned

    def _prune_empty_directories(self, directory: Path) -> None:
        current = directory
        while current != self._root and current.exists() and not any(current.iterdir()):
            current.rmdir()
            current = current.parent
