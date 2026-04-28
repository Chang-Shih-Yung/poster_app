import { describe, it, expect } from "vitest";
import { describeError } from "./errors";

describe("describeError", () => {
  it("returns Error.message verbatim", () => {
    expect(describeError(new Error("nope"))).toBe("nope");
  });

  it("returns string verbatim", () => {
    expect(describeError("plain text")).toBe("plain text");
  });

  it("joins Postgrest error fields with bullet separator", () => {
    expect(
      describeError({
        message: "permission denied",
        details: "RLS policy",
        hint: "check role",
        code: "42501",
      })
    ).toBe("permission denied · RLS policy · hint: check role · code: 42501");
  });

  it("uses message alone when other fields are missing", () => {
    expect(describeError({ message: "boom" })).toBe("boom");
  });

  it("falls back to JSON when no recognized fields exist", () => {
    expect(describeError({ random: 1 })).toBe('{"random":1}');
  });

  it("handles cyclic objects without throwing", () => {
    const cyclic: Record<string, unknown> = {};
    cyclic.self = cyclic;
    expect(describeError(cyclic)).toBe("(unknown error)");
  });

  it("coerces primitives", () => {
    expect(describeError(42)).toBe("42");
    expect(describeError(null)).toBe("null");
    expect(describeError(undefined)).toBe("undefined");
  });
});
