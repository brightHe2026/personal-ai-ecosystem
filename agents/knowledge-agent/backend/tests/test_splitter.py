import pytest

from app.splitters.text_splitter import TextSplitter


def test_split_empty_text_returns_empty_list():
    splitter = TextSplitter()

    assert splitter.split("") == []


def test_split_short_text_returns_single_chunk():
    splitter = TextSplitter(chunk_size=100, chunk_overlap=20)
    text = "hello world"

    chunks = splitter.split(text)

    assert len(chunks) == 1
    assert chunks[0]["content"] == text
    assert chunks[0]["chunk_index"] == 0


def test_split_long_text_with_overlap():
    splitter = TextSplitter(chunk_size=10, chunk_overlap=2)
    text = "abcdefghijklmnopqrstuvwxyz"

    chunks = splitter.split(text)

    assert len(chunks) == 3
    assert chunks[0]["content"] == "abcdefghij"
    assert chunks[1]["content"] == "ijklmnopqr"
    assert chunks[2]["content"] == "qrstuvwxyz"
    assert [chunk["chunk_index"] for chunk in chunks] == [0, 1, 2]


def test_splitter_rejects_invalid_overlap():
    with pytest.raises(ValueError):
        TextSplitter(chunk_size=100, chunk_overlap=100)
