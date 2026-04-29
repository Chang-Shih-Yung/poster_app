import { describe, it, expect } from "vitest";
import {
  recursivePosterCount,
  groupPath,
  flattenGroupTree,
  type GroupRow,
} from "./groupTree";

describe("recursivePosterCount", () => {
  // Tree: root1 → child1 → grandchild1
  //       root2 (no children)
  const groups = [
    { id: "root1", parent_group_id: null },
    { id: "child1", parent_group_id: "root1" },
    { id: "grandchild1", parent_group_id: "child1" },
    { id: "root2", parent_group_id: null },
  ];

  it("returns 0 for an empty group", () => {
    expect(recursivePosterCount("root1", groups, [])).toBe(0);
  });

  it("counts direct posters", () => {
    const posters = [
      { parent_group_id: "root1" },
      { parent_group_id: "root1" },
    ];
    expect(recursivePosterCount("root1", groups, posters)).toBe(2);
  });

  it("counts posters across descendants recursively", () => {
    const posters = [
      { parent_group_id: "root1" }, // 1 direct
      { parent_group_id: "child1" }, // 1 in child
      { parent_group_id: "grandchild1" }, // 1 in grandchild
      { parent_group_id: "grandchild1" }, // 2nd in grandchild
    ];
    expect(recursivePosterCount("root1", groups, posters)).toBe(4);
  });

  it("ignores posters whose parent isn't under the queried subtree", () => {
    const posters = [
      { parent_group_id: "root2" },
      { parent_group_id: null }, // direct on work, not in any group
    ];
    expect(recursivePosterCount("root1", groups, posters)).toBe(0);
  });
});

describe("groupPath", () => {
  const byId = new Map<string, GroupRow>([
    ["a", { id: "a", name: "美麗華", parent_group_id: null }],
    ["b", { id: "b", name: "2025", parent_group_id: "a" }],
    ["c", { id: "c", name: "限定", parent_group_id: "b" }],
  ]);

  it("returns 未掛群組 for null group id", () => {
    expect(groupPath(null, byId)).toBe("未掛群組");
  });

  it("returns single-segment for root group", () => {
    expect(groupPath("a", byId)).toBe("美麗華");
  });

  it("walks parents to root joining with /", () => {
    expect(groupPath("c", byId)).toBe("美麗華 / 2025 / 限定");
  });

  it("breaks early on missing parent without throwing", () => {
    const orphan = new Map<string, GroupRow>([
      ["x", { id: "x", name: "child", parent_group_id: "missing" }],
    ]);
    expect(groupPath("x", orphan)).toBe("child");
  });

  it("caps walk at depth 20 to avoid infinite cycle", () => {
    // Build a 100-deep self-cycle attempt: each name uses prev id as parent
    const cyclic = new Map<string, GroupRow>();
    cyclic.set("loop", { id: "loop", name: "L", parent_group_id: "loop" });
    // Should produce 20 "L"s joined by /
    const out = groupPath("loop", cyclic);
    expect(out.split(" / ").length).toBe(20);
  });
});

describe("flattenGroupTree", () => {
  it("returns empty for empty input", () => {
    expect(flattenGroupTree([])).toEqual([]);
  });

  it("emits root rows in display_order then alphabetical", () => {
    const rows = [
      { id: "b", name: "Beta", parent_group_id: null, display_order: 2 },
      { id: "a", name: "Alpha", parent_group_id: null, display_order: 1 },
      { id: "c", name: "Charlie", parent_group_id: null, display_order: 1 },
    ];
    const out = flattenGroupTree(rows);
    expect(out.map((x) => x.id)).toEqual(["a", "c", "b"]);
  });

  it("encodes hierarchy in the label with / separator and depth", () => {
    const rows = [
      { id: "p", name: "Parent", parent_group_id: null, display_order: 0 },
      { id: "c", name: "Child", parent_group_id: "p", display_order: 0 },
      { id: "g", name: "Grand", parent_group_id: "c", display_order: 0 },
    ];
    const out = flattenGroupTree(rows);
    expect(out).toEqual([
      { id: "p", label: "Parent", name: "Parent", depth: 0 },
      { id: "c", label: "Parent / Child", name: "Child", depth: 1 },
      { id: "g", label: "Parent / Child / Grand", name: "Grand", depth: 2 },
    ]);
  });

  it("emits child rows in DFS order under each parent", () => {
    const rows = [
      { id: "a", name: "A", parent_group_id: null, display_order: 0 },
      { id: "a1", name: "A1", parent_group_id: "a", display_order: 0 },
      { id: "a2", name: "A2", parent_group_id: "a", display_order: 1 },
      { id: "b", name: "B", parent_group_id: null, display_order: 1 },
    ];
    const out = flattenGroupTree(rows);
    expect(out.map((x) => x.id)).toEqual(["a", "a1", "a2", "b"]);
  });
});
