import "@testing-library/jest-dom/vitest";

// jsdom doesn't implement ResizeObserver / IntersectionObserver / PointerEvent —
// libraries like cmdk, Radix Popover, react-day-picker rely on them. Stub
// minimally so tests that render those components don't blow up.

if (typeof globalThis.ResizeObserver === "undefined") {
  globalThis.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  } as unknown as typeof ResizeObserver;
}

if (typeof globalThis.IntersectionObserver === "undefined") {
  globalThis.IntersectionObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
    takeRecords() {
      return [];
    }
    root = null;
    rootMargin = "";
    thresholds = [];
  } as unknown as typeof IntersectionObserver;
}

// jsdom's Element.prototype.scrollIntoView is undefined; Radix calls
// it when items get focus.
if (typeof Element.prototype.scrollIntoView !== "function") {
  Element.prototype.scrollIntoView = function () {};
}

// Radix Popover uses Pointer Events for outside-click detection. jsdom
// implements PointerEvent partially; the boolean methods that Radix
// guards on need to exist or it short-circuits to no-op.
if (typeof globalThis.PointerEvent === "undefined") {
  globalThis.PointerEvent = class extends Event {
    constructor(type: string, init?: PointerEventInit) {
      super(type, init);
    }
  } as unknown as typeof PointerEvent;
}
if (!Element.prototype.hasPointerCapture) {
  Element.prototype.hasPointerCapture = () => false;
}
if (!Element.prototype.releasePointerCapture) {
  Element.prototype.releasePointerCapture = () => {};
}
if (!Element.prototype.setPointerCapture) {
  Element.prototype.setPointerCapture = () => {};
}
