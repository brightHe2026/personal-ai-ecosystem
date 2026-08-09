# Knowledge-Agent Architecture


# 1. Vision

Knowledge-Agent is the core memory infrastructure
of Personal AI Ecosystem.

It provides:

- Knowledge ingestion
- Semantic indexing
- Retrieval
- Personal memory


# 2. Design Principles


## Source First

Original knowledge remains unchanged.


## Structured Metadata

Every knowledge item has metadata.


## Semantic Retrieval

Knowledge is retrieved by meaning,
not only keywords.


## Shared Capability

All applications can use Knowledge-Agent.


# 3. Knowledge Flow


User Knowledge Sources

        |
        v

Knowledge-Agent

        |
        v

Parser

        |
        v

Metadata Extraction

        |
        v

Embedding Generation

        |
        v

Vector Storage

        |
        v

Semantic Retrieval



# 4. Knowledge Sources


Initial supported sources:

- Obsidian Markdown
- Markdown files
- PDF documents
- Meeting notes
- Technical documents



# 5. Storage Architecture


## Original Storage

File system:

knowledge/vault


## Metadata Storage

PostgreSQL


## Vector Storage

PostgreSQL + pgvector



# 6. Agent Interface


Knowledge-Agent provides:


## Ingestion API

Input:

Documents


Output:

Indexed knowledge



## Search API

Input:

Query


Output:

Relevant knowledge chunks



# 7. Future Integration


Sales-Agent:

Customer knowledge


Stock-Agent:

Investment knowledge


Personal Assistant:

Daily memory
