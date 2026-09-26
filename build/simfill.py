#!/usr/bin/env python3
"""simfill.py - simulate the v26 gas-fill arithmetic and assert the rates.

There is no way to test this on the live server the way the other bugs were
tested. Every deploy is gated on 0 players online, and the thing being tested is
a per-player rate, so a live test would need a player to be present - which is
exactly what the gate forbids. The knockback fix (#28) has the same problem and
is simply documented as unverified.

So this models the scoreboard semantics directly instead. The value of that is
not that it proves the datapack runs; it cannot. The value is that the ARITHMETIC
is pinned down in isolation, where an off-by-one is obvious rather than hidden
inside a running server.

The trap this exists to catch: the throttle counter has to fire on every Nth
pass, and there are two natural ways to write it that differ by one.

    increment, then reset when >= N, then test == 1     fires every Nth   (used)
    increment, then test == 0                            fires every Nth+1

and a third that looks right and is wrong:

    increment, reset when >= N, then test == 1, with N=1
        -> 1 >= 1 resets to 0, never equals 1, NEVER ADDS ANY GAS

which is why the code special-cases `every` below 2 with a separate `unless`
branch rather than relying on the counter.

Every command below is transcribed from the real files. If you change
player/fill_gas or player/apply_gas, change this too - it is a model of those
lines, not of the idea behind them.

Usage: simfill.py
"""
import sys

UNSET = None  # an unset score matches no range at all


def matches(value, lo=None, hi=None):
    """Minecraft `matches` semantics for a single range.

    An unset score matches nothing, INCLUDING `..0` and `1..`. That is the whole
    reason apply_gas writes its first add as `unless ..0` rather than `if 1..`:
    a player with no rate set must behave as stock, not as frozen.
    """
    if value is UNSET:
        return False
    if lo is not None and value < lo:
        return False
    if hi is not None and value > hi:
        return False
    return True


class Player:
    def __init__(self, rate=UNSET, every=UNSET, cap=100):
        self.rate = rate
        self.every = every
        self.cap = cap
        self.cyc = 0
        self.pressure = 0

    def apply_gas(self, famt):
        """player/apply_gas, line for line."""
        n = 0
        if not matches(self.rate, hi=0):          # unless rate matches ..0
            self.pressure += famt
            n += 1
        for step in (2, 3, 4, 5):                  # if rate matches N..
            if matches(self.rate, lo=step):
                self.pressure += famt
                n += 1
        if matches(self.cap, lo=1) and self.pressure > self.cap:
            self.pressure = self.cap              # clamp
        return n

    def fill_gas(self, famt):
        """player/fill_gas, throttle section only."""
        self.cyc += 1
        if matches(self.every, lo=2) and self.cyc >= self.every:
            self.cyc = 0
        if matches(self.cyc, lo=64):
            self.cyc = 0
        ran = 0
        if not matches(self.every, lo=2):         # unless every matches 2..
            ran += self.apply_gas(famt)
        if matches(self.every, lo=2) and self.cyc == 1:
            ran += self.apply_gas(famt)
        return ran


def measure(rate, every, passes=3000, famt=1):
    """Total gas added over `passes` passes, and the highest cyc seen."""
    p = Player(rate=rate, every=every)
    total = 0
    peak = 0
    for _ in range(passes):
        total += p.fill_gas(famt)
        peak = max(peak, p.cyc)
    return total, peak


def main() -> int:
    fails = []

    def check(label, got, want):
        ok = got == want
        print(f"  {'ok  ' if ok else 'FAIL'} {label}: got {got}, want {want}")
        if not ok:
            fails.append(label)

    print("stock behaviour is unchanged (this is the regression that matters most)")
    total, _ = measure(1, 1)
    check("rate 1, every 1 -> 1x", total, 3000)
    total, _ = measure(UNSET, UNSET)
    check("both unset -> stock 1x", total, 3000)

    print("\nrate multiplier")
    for r, want in ((0, 0), (1, 3000), (2, 6000), (3, 9000), (4, 12000), (5, 15000)):
        total, _ = measure(r, 1)
        check(f"rate {r}", total, want)

    print("\nthrottle: fires on every Nth pass, and the gap is exactly one pass")
    for n, want in ((1, 3000), (2, 1500), (3, 1000), (4, 750)):
        total, _ = measure(1, n)
        check(f"every {n}", total, want)

    print("\nthe two knobs compose, so rate 2 + every 2 is exactly stock")
    total, _ = measure(2, 2)
    check("rate 2, every 2", total, 3000)
    total, _ = measure(4, 4)
    check("rate 4, every 4", total, 3000)
    total, _ = measure(3, 2)
    check("rate 3, every 2 -> 1.5x", total, 4500)

    print("\nunset is stock, NOT frozen - the failure this guards against")
    total, _ = measure(UNSET, 2)
    check("unset rate, every 2", total, 1500)
    total, _ = measure(UNSET, UNSET)
    check("unset rate, unset every", total, 3000)

    print("\nrate 0 is genuinely frozen (not one stray add)")
    total, _ = measure(0, 1)
    check("rate 0 never adds", total, 0)
    total, _ = measure(0, 2)
    check("rate 0 stays frozen when throttled", total, 0)

    print("\nthe counter cannot grow without bound")
    for every in (1, 2, 3, 4, UNSET):
        _, peak = measure(1, every, passes=20000)
        check(f"every={every} peak cyc stays small", peak <= 64, True)

    print("\nthe cap still clamps no matter how fast the fill is")
    p = Player(rate=5, every=1, cap=20)
    for _ in range(50):
        p.fill_gas(2)
    check("rate 5 against cap 20 clamps", p.pressure, 20)
    p = Player(rate=5, every=1, cap=100)
    for _ in range(50):
        p.fill_gas(2)
    check("rate 5 against cap 100 clamps", p.pressure, 100)

    print()
    if fails:
        print(f"FAILED: {len(fails)}  {fails}")
        return 1
    print("all fill-rate arithmetic checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
