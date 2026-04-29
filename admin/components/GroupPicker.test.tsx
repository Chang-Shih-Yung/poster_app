import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, cleanup, fireEvent } from "@testing-library/react";
import { buildGroupItems, GroupPicker } from "./GroupPicker";
import type { FlattenedGroup } from "@/lib/groupTree";

// Stub the server action so GroupPicker tests don't try to talk to
// Supabase. We hoist the mock with the factory function pattern Vitest
// requires.
const createGroupMock = vi.fn();
vi.mock("@/app/actions/groups", () => ({
  createGroup: (input: unknown) => createGroupMock(input),
}));

// Sonner's toast is a side effect we don't care about in these tests.
vi.mock("sonner", () => ({
  toast: { error: vi.fn(), success: vi.fn(), warning: vi.fn() },
}));

describe("buildGroupItems (pure)", () => {
  it("emits a NONE entry first", () => {
    const items = buildGroupItems([], "── 不屬於任何群組 ──");
    expect(items).toHaveLength(1);
    expect(items[0].value).toBe("__none__");
    expect(items[0].label).toBe("── 不屬於任何群組 ──");
  });

  it("inserts a separator before each new top-level block (except first)", () => {
    const groups: FlattenedGroup[] = [
      { id: "a", label: "A", name: "A", depth: 0 },
      { id: "a1", label: "A / A1", name: "A1", depth: 1 },
      { id: "b", label: "B", name: "B", depth: 0 },
      { id: "b1", label: "B / B1", name: "B1", depth: 1 },
      { id: "c", label: "C", name: "C", depth: 0 },
    ];
    const items = buildGroupItems(groups, "—");
    // items: [NONE, A, A1, B, B1, C]
    //                          ^ separator   ^ separator
    expect(items.map((i) => i.separatorBefore)).toEqual([
      undefined, // NONE
      false, // A — first top-level, no separator
      false, // A1 — child
      true,  // B — new top-level
      false, // B1 — child
      true,  // C — new top-level
    ]);
  });

  it("indents child rows proportional to depth, capped at 2", () => {
    const groups: FlattenedGroup[] = [
      { id: "a", label: "A", name: "A", depth: 0 },
      { id: "a1", label: "A/A1", name: "A1", depth: 1 },
      { id: "a1a", label: "A/A1/A1A", name: "A1A", depth: 2 },
      { id: "a1a1", label: "A/A1/A1A/X", name: "X", depth: 3 },
      { id: "a1a1a", label: "A/A1/A1A/X/Y", name: "Y", depth: 4 },
    ];
    const items = buildGroupItems(groups, "—");
    // skip the first NONE row
    expect(items[1].indentRem).toBe(0); // depth 0
    expect(items[2].indentRem).toBe(0.75); // depth 1
    expect(items[3].indentRem).toBe(1.5); // depth 2
    expect(items[4].indentRem).toBe(1.5); // depth 3 capped
    expect(items[5].indentRem).toBe(1.5); // depth 4 capped
  });

  it("uses g.label (full path) as both label and searchText", () => {
    const groups: FlattenedGroup[] = [
      { id: "a1", label: "Studio A / 2024 / IMAX", name: "IMAX", depth: 2 },
    ];
    const items = buildGroupItems(groups, "—");
    expect(items[1].label).toBe("Studio A / 2024 / IMAX");
    expect(items[1].searchText).toBe("Studio A / 2024 / IMAX");
  });
});

describe("GroupPicker createGroup integration", () => {
  beforeEach(() => {
    cleanup();
    createGroupMock.mockReset();
  });

  it("calls createGroup with parent_group_id=null and notifies parent on success", async () => {
    createGroupMock.mockResolvedValue({
      ok: true,
      data: { id: "new-id", name: "新群組", group_type: null },
    });

    const onChange = vi.fn();
    const onGroupCreated = vi.fn();

    render(
      <GroupPicker
        workId="w1"
        workName="蒼鷺與少年"
        groups={[]}
        value="__none__"
        onChange={onChange}
        onGroupCreated={onGroupCreated}
      />
    );

    // Open the popover by clicking the trigger button
    const trigger = screen.getByRole("combobox");
    fireEvent.click(trigger);

    // Click the "新增頂層群組…" action
    const addAction = await screen.findByText("新增頂層群組…");
    fireEvent.click(addAction);

    // Fill the dialog input
    const input = await screen.findByPlaceholderText("例：2024 國際版");
    fireEvent.change(input, { target: { value: "2025 限定版" } });

    // Click 建立並選取
    const submitBtn = screen.getByRole("button", { name: /建立並選取/ });
    fireEvent.click(submitBtn);

    // Wait for the async action to settle
    await vi.waitFor(() => {
      expect(createGroupMock).toHaveBeenCalledWith({
        work_id: "w1",
        parent_group_id: null,
        name: "2025 限定版",
      });
    });

    // After success, parent should be notified and the new group selected
    await vi.waitFor(() => {
      expect(onGroupCreated).toHaveBeenCalledWith("new-id");
      expect(onChange).toHaveBeenCalledWith("new-id");
    });
  });

  it("does not submit when the name is whitespace-only", async () => {
    createGroupMock.mockResolvedValue({ ok: true, data: { id: "x" } });

    render(
      <GroupPicker
        workId="w1"
        groups={[]}
        value="__none__"
        onChange={vi.fn()}
      />
    );

    fireEvent.click(screen.getByRole("combobox"));
    const addAction = await screen.findByText("新增頂層群組…");
    fireEvent.click(addAction);

    const input = await screen.findByPlaceholderText("例：2024 國際版");
    fireEvent.change(input, { target: { value: "   " } });

    const submitBtn = screen.getByRole("button", { name: /建立並選取/ });
    // Empty / whitespace name → button should be disabled
    expect(submitBtn).toBeDisabled();
    expect(createGroupMock).not.toHaveBeenCalled();
  });
});
