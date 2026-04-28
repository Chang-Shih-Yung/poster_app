import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { isAdminEmail } from "./auth";

describe("isAdminEmail", () => {
  const original = process.env.ADMIN_EMAILS;

  beforeEach(() => {
    process.env.ADMIN_EMAILS = "alice@example.com, Bob@Example.com,carol@example.com";
  });

  afterEach(() => {
    process.env.ADMIN_EMAILS = original;
  });

  it("matches lower-cased email", () => {
    expect(isAdminEmail("alice@example.com")).toBe(true);
  });

  it("matches case-insensitively", () => {
    expect(isAdminEmail("ALICE@EXAMPLE.COM")).toBe(true);
    expect(isAdminEmail("bob@example.com")).toBe(true);
  });

  it("trims whitespace from whitelist entries", () => {
    expect(isAdminEmail("Bob@Example.com")).toBe(true);
  });

  it("rejects unknown email", () => {
    expect(isAdminEmail("eve@example.com")).toBe(false);
  });

  it("rejects null/undefined/empty", () => {
    expect(isAdminEmail(null)).toBe(false);
    expect(isAdminEmail(undefined)).toBe(false);
    expect(isAdminEmail("")).toBe(false);
  });

  it("returns false when whitelist is empty", () => {
    process.env.ADMIN_EMAILS = "";
    expect(isAdminEmail("alice@example.com")).toBe(false);
  });

  it("ignores empty entries from extra commas", () => {
    process.env.ADMIN_EMAILS = ",,alice@example.com,,";
    expect(isAdminEmail("alice@example.com")).toBe(true);
  });
});
