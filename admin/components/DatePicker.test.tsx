import { describe, it, expect } from "vitest";
import { parseLocalDate, toIsoDate } from "./DatePicker";

/**
 * Regression coverage for the timezone-shift trap that bites every
 * <input type="date"> migration: `new Date("2026-04-29")` parses as
 * UTC and renders the day before in negative-offset zones.
 *
 * These tests should pass regardless of the host timezone so we don't
 * mock TZ — instead we assert the local components directly, which
 * are invariant.
 */
describe("parseLocalDate", () => {
  it("parses YYYY-MM-DD as local midnight", () => {
    const d = parseLocalDate("2026-04-29");
    expect(d).not.toBeNull();
    expect(d!.getFullYear()).toBe(2026);
    expect(d!.getMonth()).toBe(3); // 0-indexed; 3 = April
    expect(d!.getDate()).toBe(29);
    expect(d!.getHours()).toBe(0);
  });

  it("returns null for empty string", () => {
    expect(parseLocalDate("")).toBeNull();
  });

  it("returns null for non-date strings", () => {
    expect(parseLocalDate("not a date")).toBeNull();
    expect(parseLocalDate("2026/04/29")).toBeNull(); // wrong separator
    expect(parseLocalDate("2026-4-29")).toBeNull(); // missing zero pad
  });

  it("returns null for impossible months / days", () => {
    expect(parseLocalDate("2026-13-01")).toBeNull(); // month 13
    expect(parseLocalDate("2026-00-01")).toBeNull(); // month 0
    expect(parseLocalDate("2026-04-32")).toBeNull(); // day 32
    expect(parseLocalDate("2026-04-00")).toBeNull(); // day 0
  });

  it("rejects rollover dates that JS Date silently accepts", () => {
    // Date(2026, 1, 30) in JS rolls over to Mar 2 — we reject it.
    expect(parseLocalDate("2026-02-30")).toBeNull();
    // Apr 31 → May 1
    expect(parseLocalDate("2026-04-31")).toBeNull();
  });

  it("accepts leap day in a leap year", () => {
    const d = parseLocalDate("2024-02-29");
    expect(d).not.toBeNull();
    expect(d!.getMonth()).toBe(1);
    expect(d!.getDate()).toBe(29);
  });

  it("rejects leap day in a non-leap year", () => {
    expect(parseLocalDate("2025-02-29")).toBeNull();
  });
});

describe("toIsoDate", () => {
  it("formats local date components as YYYY-MM-DD", () => {
    const d = new Date(2026, 3, 29); // local Apr 29
    expect(toIsoDate(d)).toBe("2026-04-29");
  });

  it("zero-pads month and day", () => {
    const d = new Date(2026, 0, 5);
    expect(toIsoDate(d)).toBe("2026-01-05");
  });

  it("roundtrips with parseLocalDate", () => {
    const cases = ["2026-04-29", "1999-12-31", "2024-02-29", "2026-01-01"];
    for (const c of cases) {
      const parsed = parseLocalDate(c);
      expect(parsed).not.toBeNull();
      expect(toIsoDate(parsed!)).toBe(c);
    }
  });
});
