"""Brute-force protection for /auth/login: lock a (key) after repeated failures.

In-memory and per-process: enough to stop online guessing against one server.
(For several servers behind a load balancer this would move to a shared store.)
"""

import time
from collections import defaultdict, deque


class LoginThrottle:
    def __init__(self, max_failures: int = 5, window_seconds: int = 900, clock=time.monotonic):
        self.max_failures = max_failures
        self.window = window_seconds
        self._clock = clock
        self._failures: dict[str, deque[float]] = defaultdict(deque)

    def _prune(self, key: str) -> deque[float]:
        q = self._failures[key]
        cutoff = self._clock() - self.window
        while q and q[0] <= cutoff:
            q.popleft()
        if not q:
            self._failures.pop(key, None)
            return deque()
        return q

    def is_locked(self, key: str) -> bool:
        return len(self._prune(key)) >= self.max_failures

    def retry_after(self, key: str) -> int:
        q = self._prune(key)
        if len(q) < self.max_failures:
            return 0
        return max(1, int(q[0] + self.window - self._clock()))

    def record_failure(self, key: str) -> None:
        self._prune(key)
        self._failures[key].append(self._clock())

    def reset(self, key: str) -> None:
        self._failures.pop(key, None)
