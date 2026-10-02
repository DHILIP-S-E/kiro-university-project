import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from app.services.login_throttle import LoginThrottle


class Clock:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


def make(**kw):
    c = Clock()
    return LoginThrottle(clock=c, **kw), c


def test_locks_after_max_failures():
    t, _ = make(max_failures=3)
    for _ in range(2):
        t.record_failure("a")
    assert not t.is_locked("a")
    t.record_failure("a")
    assert t.is_locked("a")


def test_other_keys_unaffected():
    t, _ = make(max_failures=2)
    t.record_failure("a"); t.record_failure("a")
    assert t.is_locked("a") and not t.is_locked("b")


def test_lock_expires_after_the_window():
    t, c = make(max_failures=2, window_seconds=60)
    t.record_failure("a"); t.record_failure("a")
    assert t.is_locked("a")
    c.t += 61
    assert not t.is_locked("a")


def test_retry_after_counts_down():
    t, c = make(max_failures=2, window_seconds=60)
    t.record_failure("a"); t.record_failure("a")
    assert t.retry_after("a") == 60
    c.t += 20
    assert t.retry_after("a") == 40
    c.t += 100
    assert t.retry_after("a") == 0


def test_success_resets():
    t, _ = make(max_failures=2)
    t.record_failure("a"); t.record_failure("a")
    t.reset("a")
    assert not t.is_locked("a")


def test_old_failures_do_not_accumulate_forever():
    t, c = make(max_failures=3, window_seconds=60)
    for _ in range(10):
        t.record_failure("a")
        c.t += 61  # each failure ages out before the next
    assert not t.is_locked("a")
