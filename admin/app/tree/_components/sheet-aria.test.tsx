import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, cleanup } from "@testing-library/react";
import { FormSheet } from "./FormSheet";
import { ItemActionsBundle } from "./ItemActionsBundle";

/**
 * Regression: ISSUE-001 — Radix Dialog warns when DialogContent has
 * neither a Description child nor an explicit aria-describedby prop.
 * Found by /qa on 2026-04-28
 * Report: .gstack/qa-reports/qa-report-localhost-2026-04-28.md
 *
 * Both FormSheet and ItemActionsBundle conditionally render a
 * SheetDescription. When the consumer omits the description (e.g.
 * a simple rename form), the conditional skips the element and Radix
 * complains. The fix is to pass aria-describedby={undefined} to
 * SheetContent in that branch — these tests guard the fix.
 */

describe("Sheet aria-describedby (ISSUE-001)", () => {
  let warn: ReturnType<typeof vi.spyOn>;
  let error: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    error = vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    cleanup();
    warn.mockRestore();
    error.mockRestore();
  });

  function getDescriptionWarnings() {
    // Radix logs the warning via console.error. Some Radix builds use
    // console.warn — check both to keep the test stable across versions.
    const calls = [...warn.mock.calls, ...error.mock.calls];
    return calls.filter((args: unknown[]) =>
      args.some(
        (a: unknown) =>
          typeof a === "string" &&
          /Description|aria-describedby/i.test(a)
      )
    );
  }

  it("FormSheet without description does not log Radix description warning", () => {
    render(
      <FormSheet
        open
        onOpenChange={() => {}}
        title="重新命名作品"
        // intentionally no description
        fields={[
          { key: "name", kind: "text", label: "名稱", required: true },
        ]}
        onSubmit={async () => {}}
      />
    );
    expect(getDescriptionWarnings()).toHaveLength(0);
  });

  it("FormSheet WITH description renders the description element", () => {
    const { getByText } = render(
      <FormSheet
        open
        onOpenChange={() => {}}
        title="新增分類"
        description="分類底下至少要有一部作品"
        fields={[
          { key: "name", kind: "text", label: "名稱", required: true },
        ]}
        onSubmit={async () => {}}
      />
    );
    expect(getByText("分類底下至少要有一部作品")).toBeInTheDocument();
    expect(getDescriptionWarnings()).toHaveLength(0);
  });

  it("ItemActionsBundle without description does not log warning", () => {
    type Item = { id: string };
    const item: Item = { id: "x" };
    render(
      <ItemActionsBundle<Item>
        item={item}
        onClose={() => {}}
        title="某個項目"
        // intentionally no description
        actions={[
          {
            kind: "instant",
            icon: <span>i</span>,
            label: "刪除",
            run: async () => ({ ok: true, data: undefined }),
          },
        ]}
      />
    );
    expect(getDescriptionWarnings()).toHaveLength(0);
  });
});
