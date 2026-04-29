import { describe, it, expect, beforeEach, vi } from "vitest";
import {
  NONE,
  fromSentinel,
  isReady,
  newDraft,
  rejectionReason,
  type DraftPoster,
} from "./_shared";

// jsdom doesn't implement URL.createObjectURL; stub before any test
// that calls newDraft (which calls it).
beforeEach(() => {
  if (!("createObjectURL" in URL)) {
    Object.defineProperty(URL, "createObjectURL", {
      value: vi.fn(() => "blob:mock"),
      configurable: true,
    });
  } else {
    vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:mock");
  }
});

function fakeFile(
  name = "x.jpg",
  size = 1024,
  type = "image/jpeg"
): File {
  return new File([new Uint8Array(size)], name, { type });
}

describe("fromSentinel", () => {
  it("converts NONE sentinel to null", () => {
    expect(fromSentinel(NONE)).toBeNull();
  });
  it("converts empty string to null", () => {
    expect(fromSentinel("")).toBeNull();
  });
  it("passes through real values", () => {
    expect(fromSentinel("A1")).toBe("A1");
    expect(fromSentinel("anniversary")).toBe("anniversary");
  });
});

describe("newDraft", () => {
  it("creates a draft with sane defaults", () => {
    const f = fakeFile();
    const d = newDraft(f);
    expect(d.file).toBe(f);
    expect(d.name).toBe("");
    expect(d.work_id).toBe("");
    expect(d.parent_group_id).toBe(NONE);
    expect(d.region).toBe("TW"); // DEFAULT_REGION
    expect(d.size_type).toBe(NONE);
    expect(d.licensed).toBe(true); // licensed default flips to true
    expect(d.signed).toBe(false);
    expect(d.numbered).toBe(false);
    expect(d.linen_backed).toBe(false);
    expect(d.status).toBe("idle");
    expect(d.localId).toMatch(/^[a-z0-9]+$/);
  });

  it("applies the supplied defaults over the bare defaults", () => {
    const d = newDraft(fakeFile(), {
      work_id: "w1",
      parent_group_id: "g1",
      region: "JP",
      year: "2025",
      size_type: "A1",
    });
    expect(d.work_id).toBe("w1");
    expect(d.parent_group_id).toBe("g1");
    expect(d.region).toBe("JP");
    expect(d.year).toBe("2025");
    expect(d.size_type).toBe("A1");
  });

  it("emits a unique localId per draft", () => {
    const a = newDraft(fakeFile());
    const b = newDraft(fakeFile());
    expect(a.localId).not.toBe(b.localId);
  });
});

describe("isReady", () => {
  function draftWith(patch: Partial<DraftPoster>): DraftPoster {
    return { ...newDraft(fakeFile()), ...patch };
  }

  it("requires status === idle", () => {
    expect(isReady(draftWith({ status: "done", name: "X", work_id: "w" }))).toBe(false);
    expect(isReady(draftWith({ status: "creating", name: "X", work_id: "w" }))).toBe(false);
    expect(isReady(draftWith({ status: "uploading", name: "X", work_id: "w" }))).toBe(false);
    expect(isReady(draftWith({ status: "error", name: "X", work_id: "w" }))).toBe(false);
    expect(isReady(draftWith({ status: "image_failed", name: "X", work_id: "w" }))).toBe(false);
  });

  it("requires non-blank name", () => {
    expect(isReady(draftWith({ name: "", work_id: "w" }))).toBe(false);
    expect(isReady(draftWith({ name: "   ", work_id: "w" }))).toBe(false);
  });

  it("requires non-empty work_id", () => {
    expect(isReady(draftWith({ name: "X", work_id: "" }))).toBe(false);
  });

  it("returns true when idle + name + work_id all set", () => {
    expect(isReady(draftWith({ name: "X", work_id: "w" }))).toBe(true);
  });
});

describe("rejectionReason", () => {
  it("rejects empty files", () => {
    const f = fakeFile("zero.jpg", 0, "image/jpeg");
    expect(rejectionReason(f)).toMatch(/檔案大小為 0/);
  });

  it("rejects files > 50MB", () => {
    const big = fakeFile("big.jpg", 51 * 1024 * 1024, "image/jpeg");
    const reason = rejectionReason(big);
    expect(reason).toMatch(/檔案太大/);
    expect(reason).toMatch(/上限 50MB/);
  });

  it("rejects HEIC by mime type when canvas can't decode", () => {
    const f = fakeFile("photo.HEIC", 1024, "image/heic");
    expect(rejectionReason(f)).toMatch(/不支援 HEIC/);
  });

  it("rejects HEIC by extension even when type is empty", () => {
    const f = fakeFile("photo.heic", 1024, "");
    expect(rejectionReason(f)).toMatch(/不支援 HEIC/);
  });

  it("rejects HEIF", () => {
    const f = fakeFile("photo.heif", 1024, "image/heif");
    expect(rejectionReason(f)).toMatch(/不支援 HEIC/);
  });

  it("rejects non-image types", () => {
    const f = fakeFile("doc.pdf", 1024, "application/pdf");
    expect(rejectionReason(f)).toMatch(/不支援/);
  });

  it("accepts JPEG / PNG / WebP", () => {
    expect(rejectionReason(fakeFile("a.jpg", 1024, "image/jpeg"))).toBeNull();
    expect(rejectionReason(fakeFile("a.png", 1024, "image/png"))).toBeNull();
    expect(rejectionReason(fakeFile("a.webp", 1024, "image/webp"))).toBeNull();
  });
});
