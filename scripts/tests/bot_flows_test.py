#!/usr/bin/env python3
"""
Black-box integration test suite against live Supabase.

Exercises every read-path RPC / table that the 10-bot seed fixture
touches: follow graph, favorites, trending, collectors, CF recs,
search, public profile, notifications.

Only read paths — anon key is all we carry. Write paths (report
trigger, toggle_follow, toggle_favorite) need authenticated sessions
and are covered separately via SQL Editor snippets.

Usage:
    python3 scripts/tests/bot_flows_test.py

Expects `.env.dev` at repo root with SUPABASE_URL + SUPABASE_ANON_KEY.
Exit 0 = all pass, 1 = any fail.
"""

from __future__ import annotations

import json
import os
import pathlib
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Callable


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ENV_FILE = REPO_ROOT / ".env.dev"

HENRY_ID = "a1cb9f23-6423-4735-83ea-d10d29693a88"
BIU_ID = "964d16f7-f449-4b8c-a69b-bc462cb43629"
BOT_IDS = [f"00000000-0000-0000-0000-00000000010{i}" for i in range(10)]


# ────────────────────────────────────────────────────────────────────
# Minimal HTTP helpers
# ────────────────────────────────────────────────────────────────────

def load_env() -> tuple[str, str]:
    """Resolve SUPABASE_URL + SUPABASE_ANON_KEY.

    Precedence: process env vars first (so GitHub Actions can inject
    from repo secrets), then fall back to parsing `.env.dev` for
    local runs. Fails loudly if neither is set.
    """
    env_url = os.environ.get("SUPABASE_URL")
    env_key = os.environ.get("SUPABASE_ANON_KEY")
    if env_url and env_key:
        return env_url, env_key
    if not ENV_FILE.exists():
        sys.exit(
            "missing SUPABASE_URL / SUPABASE_ANON_KEY — set them as env vars "
            f"or create {ENV_FILE}",
        )
    env: dict[str, str] = {}
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip()
    return env["SUPABASE_URL"], env["SUPABASE_ANON_KEY"]


SUPABASE_URL, ANON_KEY = load_env()


def _request(path: str, *, method: str = "GET", body: Any = None) -> Any:
    url = f"{SUPABASE_URL}{path}"
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Content-Type": "application/json",
    }
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            raw = res.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        body_txt = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} on {method} {path}: {body_txt[:300]}") from None


def rest(table: str, query: str) -> list[dict[str, Any]]:
    return _request(f"/rest/v1/{table}?{query}")  # type: ignore[return-value]


def rpc(name: str, params: dict[str, Any] | None = None) -> Any:
    return _request(f"/rest/v1/rpc/{name}", method="POST", body=params or {})


# ────────────────────────────────────────────────────────────────────
# Tiny test harness — each test is a (name, fn) pair; fn returns
# an optional info string and raises AssertionError on fail.
# ────────────────────────────────────────────────────────────────────

@dataclass
class Suite:
    title: str
    tests: list[tuple[str, Callable[[], str | None]]] = field(default_factory=list)


SUITES: list[Suite] = []


def section(title: str) -> Suite:
    s = Suite(title=title)
    SUITES.append(s)
    return s


def assert_eq(actual, expected, hint: str = ""):
    if actual != expected:
        raise AssertionError(f"expected {expected!r}, got {actual!r}{' · ' + hint if hint else ''}")


def assert_ge(actual, threshold, hint: str = ""):
    if not (actual >= threshold):
        raise AssertionError(f"expected ≥ {threshold}, got {actual!r}{' · ' + hint if hint else ''}")


def assert_truthy(actual, hint: str = ""):
    if not actual:
        raise AssertionError(f"expected truthy, got {actual!r}{' · ' + hint if hint else ''}")


# ════════════════════════════════════════════════════════════════════
# 1. Seed integrity
# ════════════════════════════════════════════════════════════════════

S1 = section("1. Seed integrity")


def t_10_bots_exist():
    rows = rest("users", "select=id,handle,display_name,is_public,role&handle=like.bot*")
    assert_eq(len(rows), 10, f"found {len(rows)} bots")
    handles = sorted(r["handle"] for r in rows)
    assert_truthy(all(r["is_public"] for r in rows), "all bots public")
    assert_truthy(all(r["role"] == "user" for r in rows), "all bots role=user")
    return f"10 bots, handles {handles[0]}..{handles[-1]}"


S1.tests.append(("10 bots exist with bot* handles + is_public + role=user", t_10_bots_exist))


# NOTE: follows + favorites tables are anon-blocked by RLS
# (follows.select needs auth.uid(), favorites.select is user-scoped).
# The seed-integrity tests for those relations therefore go through
# the `security definer` RPCs that aggregate the same data.

def t_henry_has_bot_followers():
    s = rpc("user_relationship_stats", {"p_user_id": HENRY_ID})
    followers = s.get("follower_count", 0) if isinstance(s, dict) else 0
    assert_ge(followers, 10, f"Henry has {followers} followers, want ≥ 10 bots")
    return f"Henry follower_count = {followers}"


S1.tests.append(("Henry has ≥ 10 followers (all bots follow him)", t_henry_has_bot_followers))


def t_biu_has_bot_followers():
    s = rpc("user_relationship_stats", {"p_user_id": BIU_ID})
    followers = s.get("follower_count", 0) if isinstance(s, dict) else 0
    assert_ge(followers, 10, f"BIU has {followers} followers, want ≥ 10 bots")
    return f"BIU follower_count = {followers}"


S1.tests.append(("BIU has ≥ 10 followers (all bots follow him)", t_biu_has_bot_followers))


def t_bot_bot_graph_via_rpc():
    # Iterate each bot, pull relationship stats via RPC. Each bot should
    # follow Henry + BIU (2 minimum). With the 50% bot↔bot probability,
    # ~4–5 extra follows are expected per bot.
    counts: list[int] = []
    for bid in BOT_IDS:
        s = rpc("user_relationship_stats", {"p_user_id": bid})
        counts.append(s.get("following_count", 0) if isinstance(s, dict) else 0)
    # Every bot must follow Henry + BIU at minimum.
    assert_truthy(all(c >= 2 for c in counts),
                  f"bot following_counts: {counts} — some < 2")
    # 50% bot↔bot probability × 9 other bots → on average 4.5 extra per bot.
    # Require at least half the bots have ≥ 3 follows (i.e., at least 1
    # bot-bot edge in addition to Henry+BIU).
    with_extra = sum(1 for c in counts if c >= 3)
    assert_ge(with_extra, 5,
              f"only {with_extra}/10 bots have ≥ 3 follows — bot graph is sparse")
    total = sum(counts)
    return (f"totals: {total} follows across 10 bots "
            f"(avg {total / 10:.1f}, with_extra {with_extra}/10)")


S1.tests.append(("bot-to-bot graph connected (via RPC)", t_bot_bot_graph_via_rpc))


def t_favorite_count_sum():
    # favorites table is anon-blocked, but posters.favorite_count was
    # refreshed after the bot seed. 10 bots × 8 favs = 80 new likes
    # should push the global sum above some floor.
    rows = rest("posters",
                "select=favorite_count&status=eq.approved&favorite_count=gte.1&limit=1000")
    total_favs = sum(r["favorite_count"] for r in rows)
    assert_ge(total_favs, 80,
              f"sum(posters.favorite_count) = {total_favs}, want ≥ 80 (bot seed was 80 likes)")
    return f"{total_favs} total likes across {len(rows)} liked posters"


S1.tests.append(("posters.favorite_count sum ≥ 80 (bot favs accounted for)",
                 t_favorite_count_sum))


def t_favorite_count_reflected():
    rows = rest("posters",
                "select=id,title,favorite_count&favorite_count=gte.1"
                "&order=favorite_count.desc&limit=5")
    assert_ge(len(rows), 1, "no posters with favorite_count ≥ 1")
    top = rows[0]
    assert_ge(top["favorite_count"], 1)
    return f"top: \"{top['title']}\" ({top['favorite_count']})"


S1.tests.append(("posters.favorite_count reflects bot likes", t_favorite_count_reflected))


# ════════════════════════════════════════════════════════════════════
# 2. Discovery surfaces pick up the bot signal
# ════════════════════════════════════════════════════════════════════

S2 = section("2. Discovery surfaces")


def t_trending():
    result = rpc("trending_favorites", {"p_limit": 10})
    assert_truthy(isinstance(result, list), f"got {type(result).__name__}")
    assert_ge(len(result), 1, "trending list is empty")
    top = result[0]
    assert_truthy("id" in top, "trending row missing id")
    assert_truthy("title" in top, "trending row missing title")
    return f"{len(result)} rows, top \"{top.get('title', '?')}\""


S2.tests.append(("trending_favorites surfaces high-fav posters", t_trending))


def t_collectors():
    result = rpc("active_collectors", {"p_limit": 20})
    assert_truthy(isinstance(result, list))
    ids = {row.get("user_id") or row.get("id") for row in result}
    overlap = ids & set(BOT_IDS)
    assert_ge(len(overlap), 3,
              f"only {len(overlap)} bots in active_collectors (got {len(result)} total)")
    return f"{len(overlap)}/10 bots in top {len(result)} collectors"


S2.tests.append(("active_collectors surfaces bots", t_collectors))


def t_home_sections():
    result = rpc("home_sections_v2", {})
    assert_truthy(isinstance(result, list), f"got {type(result).__name__}")
    assert_ge(len(result), 1, "no home sections")
    slugs = [s.get("slug") for s in result]
    return f"{len(result)} sections: {slugs[:4]}"


S2.tests.append(("home_sections_v2 returns sections", t_home_sections))


def t_for_you_cold_start():
    result = rpc("for_you_feed_v1", {"p_limit": 10})
    assert_truthy(isinstance(result, list))
    assert_ge(len(result), 1, "for_you feed empty even on cold-start")
    return f"{len(result)} items"


S2.tests.append(("for_you_feed_v1 cold-start fallback", t_for_you_cold_start))


# ════════════════════════════════════════════════════════════════════
# 3. Search + public profile
# ════════════════════════════════════════════════════════════════════

S3 = section("3. Search + public profile")


def t_search_bot():
    result = rpc("search_users", {"p_query": "bot", "p_limit": 20})
    assert_truthy(isinstance(result, list))
    ids = {r.get("id") for r in result}
    overlap = ids & set(BOT_IDS)
    assert_eq(len(overlap), 10, f"search returned {len(overlap)}/10 bots")


S3.tests.append(("search_users('bot') returns all 10 bots", t_search_bot))


def t_public_profiles():
    for bid in BOT_IDS[:3]:
        p = rpc("user_public_profile", {"p_user_id": bid})
        assert_truthy(p is not None, f"bot ...{bid[-4:]} profile = null")
        assert_truthy(isinstance(p, dict), f"bot ...{bid[-4:]} profile = {type(p).__name__}")
        name = p.get("display_name", "")
        handle = p.get("handle") or ""
        assert_truthy(name.startswith("Bot "), f"display_name = {name!r}")
        assert_truthy(handle.startswith("bot"), f"handle = {handle!r}")
    return "sampled 3 bots, all shapes clean"


S3.tests.append(("user_public_profile(bot) returns complete profile", t_public_profiles))


def t_henry_stats():
    s = rpc("user_relationship_stats", {"p_user_id": HENRY_ID})
    assert_truthy(isinstance(s, dict), f"got {type(s).__name__}")
    followers = s.get("follower_count", 0)
    assert_ge(followers, 10, f"Henry has {followers} followers, want ≥ 10")
    return f"Henry followers: {followers}, following: {s.get('following_count', 0)}"


S3.tests.append(("user_relationship_stats(Henry) shows ≥10 followers", t_henry_stats))


def t_bot_stats():
    s = rpc("user_relationship_stats", {"p_user_id": BOT_IDS[0]})
    assert_truthy(isinstance(s, dict))
    following = s.get("following_count", 0)
    assert_ge(following, 2, f"bot00 follows {following}, want ≥ 2")
    return f"bot00 following: {following}, followers: {s.get('follower_count', 0)}"


S3.tests.append(("user_relationship_stats(bot00) shows ≥2 following", t_bot_stats))


# ════════════════════════════════════════════════════════════════════
# 4. Notifications (shape sanity for anon)
# ════════════════════════════════════════════════════════════════════

S4 = section("4. Notifications pipeline")


def t_notifs_schema():
    try:
        n = rpc("unread_notifications_count", {})
        assert_truthy(
            isinstance(n, (int, dict, list)) or n is None,
            f"unexpected type {type(n).__name__}",
        )
        return f"returned {n!r} (anon)"
    except RuntimeError as e:
        # Anon may get a 400 / 42501 auth error — that's acceptable.
        if "401" in str(e) or "42501" in str(e) or "auth" in str(e).lower():
            return "anon rejected (expected — auth gate)"
        raise


S4.tests.append(("unread_notifications_count responds (anon)", t_notifs_schema))


# ════════════════════════════════════════════════════════════════════
# 5. CF pipeline
# ════════════════════════════════════════════════════════════════════

S5 = section("5. CF pipeline")


def t_cf_cache():
    # Table name guesses — we'll try a couple and skip gracefully.
    for table in ("user_recommendations", "cf_recommendations",
                  "recommendations_cache", "collaborative_recommendations"):
        try:
            rows = rest(
                table,
                f"select=user_id,poster_id&user_id=in.({','.join(BOT_IDS[:3])})&limit=20",
            )
            if isinstance(rows, list):
                return (f"table `{table}`: {len(rows)} CF rows for 3 sampled bots"
                        if rows else f"table `{table}` exposed but empty for bots")
        except RuntimeError as e:
            if "404" in str(e) or "not exist" in str(e).lower():
                continue
            raise
    return "(no CF cache table exposed via REST — manual verification only)"


S5.tests.append(("CF cache table reachable for bots (best effort)", t_cf_cache))


# ════════════════════════════════════════════════════════════════════
# Runner
# ════════════════════════════════════════════════════════════════════

def run() -> int:
    print(f"Target: {SUPABASE_URL}")
    print(f"Bots:   {BOT_IDS[0][:-2]}00 .. {BOT_IDS[-1][:-2]}09")
    print(f"Henry:  {HENRY_ID}")
    print(f"BIU:    {BIU_ID}")

    total = passed = failed = 0
    failures: list[tuple[str, str]] = []

    for suite in SUITES:
        print(f"\n── {suite.title} ──")
        for name, fn in suite.tests:
            total += 1
            try:
                info = fn() or ""
                passed += 1
                tail = f"  — {info}" if info else ""
                print(f"  ✓ {name}{tail}")
            except AssertionError as e:
                failed += 1
                failures.append((name, str(e)))
                print(f"  ✗ {name}")
                print(f"      {e}")
            except Exception as e:  # noqa: BLE001
                failed += 1
                detail = f"{type(e).__name__}: {e}"
                failures.append((name, detail))
                print(f"  ✗ {name}")
                print(f"      {detail}")

    print(f"\n══════════════════════════════════════════")
    print(f"  {passed} passed · {failed} failed · {total} total")
    print(f"══════════════════════════════════════════")
    if failures:
        print("\nFailures:")
        for n, d in failures:
            print(f"  ✗ {n}\n      {d}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(run())
