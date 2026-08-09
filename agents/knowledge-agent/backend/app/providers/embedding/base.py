from abc import ABC, abstractmethod
from typing import List


class EmbeddingProvider(ABC):
    """
    Embedding Provider 抽象接口
    """


    @abstractmethod
    def embed(
        self,
        text: str
    ) -> List[float]:
        """
        单文本向量化
        """
        pass



    @abstractmethod
    def embed_batch(
        self,
        texts: List[str]
    ) -> List[List[float]]:
        """
        批量向量化
        """
        pass
