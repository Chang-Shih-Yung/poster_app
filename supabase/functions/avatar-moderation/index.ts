// ═══════════════════════════════════════════════════════════════════
// avatar-moderation — server-side NSFW classification of an avatar.
// ═══════════════════════════════════════════════════════════════════
//
// Strategy: open-source model hosted on Hugging Face Inference API
// (FREE 30K req/month). No client-side bundle, no Supabase Pro
// required. Falls back to "ok" if HF is unreachable so legitimate
// uploads don't get blocked by an outage — admin review queue
// (server-side reports trigger) catches anything the model misses.
//
// Input  POST body: { "user_id": "uuid", "image_url": "https://..." }
// Output 200: { "status": "ok" | "pending_review" | "rejected" }
//        400: { "error": "..." }
//
// Setup:
//   1) Sign up at huggingface.co (free), get an API token
//   2) supabase secrets set HF_API_TOKEN=hf_xxx
//   3) supabase functions deploy avatar-moderation --no-verify-jwt
//   4) Front-end calls this RIGHT AFTER avatar upload finishes; the
//      function writes back avatar_status. Front-end refetches profile.
//
// Model: Falconsai/nsfw_image_detection — open-source, Apache 2.0.
// Returns a BINARY classification: `normal` vs `nsfw`, each with a
// 0..1 confidence score. Earlier versions of this file assumed the
// 5-class NSFWJS scheme (porn/hentai/sexy/drawing/neutral) — that
// was wrong; Falconsai collapses everything into one score. The
// classify() function was patched in v19 round 4 to match.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const HF_MODEL = "Falconsai/nsfw_image_detection";
// v19 round 4: HuggingFace retired the legacy `api-inference` host in
// early 2025 — classic requests now 404 with an Express "Cannot POST"
// page. Serverless inference moved under the Inference Providers
// router. Task-based classic endpoints live at:
//   https://router.huggingface.co/hf-inference/models/{model_id}
// Binary image body + `Authorization: Bearer <HF token>` otherwise
// identical to the old shape.
const HF_URL = `https://router.huggingface.co/hf-inference/models/${HF_MODEL}`;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

interface Body {
  user_id: string;
  image_url: string;
}

interface HFLabel {
  label: string;
  score: number;
}

type Status = "ok" | "pending_review" | "rejected";

function classify(labels: HFLabel[]): Status {
  // Falconsai returns two rows: `normal` + `nsfw`. We only care
  // about the nsfw confidence.
  const nsfw = labels.find((l) => l.label.toLowerCase() === "nsfw")
    ?.score ?? 0;

  // Hard reject when the model is very confident it's NSFW.
  // Threshold picked so a stock portrait (~0.001) / landscape
  // (~0.0002) never trips; an artistic-nude painting typically
  // scores 0.85+ on this model.
  if (nsfw > 0.75) return "rejected";

  // Borderline — flag for admin review. Catches suggestive-but-
  // not-explicit content (beach bikini, athletic wear, etc.) that
  // we don't want to auto-reject but want a human to eyeball.
  if (nsfw > 0.35) return "pending_review";

  return "ok";
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), {
      status: 405,
    });
  }
  let body: Body & { debug?: boolean };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "bad json" }), {
      status: 400,
    });
  }
  if (!body.user_id || !body.image_url) {
    return new Response(
      JSON.stringify({ error: "user_id + image_url required" }),
      { status: 400 },
    );
  }

  let status: Status = "ok";
  // Diagnostic fields — returned only when `debug: true` is in the
  // POST body. Lets us trace "which branch did we hit" without
  // having to pull Edge Function logs. Never surfaced to end users.
  let diagnostics: Record<string, unknown> = {};

  try {
    // Fetch the uploaded image and forward to HF inference.
    const imgRes = await fetch(body.image_url);
    if (!imgRes.ok) throw new Error(`image fetch ${imgRes.status}`);
    const bytes = new Uint8Array(await imgRes.arrayBuffer());
    diagnostics.image_bytes = bytes.length;

    const hfRes = await fetch(HF_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("HF_API_TOKEN")}`,
        "Content-Type": "application/octet-stream",
      },
      body: bytes,
    });
    diagnostics.hf_status = hfRes.status;

    if (!hfRes.ok) {
      // Model load may take a few seconds on cold start — HF returns 503
      // with `estimated_time`. Treat as transient: leave status 'ok'
      // and let the user-report path catch real violators.
      const errBody = await hfRes.text();
      diagnostics.hf_error_body = errBody.slice(0, 500);
      console.warn(`HF returned ${hfRes.status}, defaulting to ok`);
    } else {
      const raw = await hfRes.json();
      diagnostics.hf_raw = raw;
      const labels = raw as HFLabel[];
      status = classify(labels);
    }
  } catch (err) {
    // Network error / timeout. Don't block the upload — fail open.
    diagnostics.exception = String(err);
    console.warn("moderation failed, defaulting to ok:", err);
  }

  // Persist the verdict.
  const { error } = await supabase
    .from("users")
    .update({ avatar_status: status })
    .eq("id", body.user_id);
  if (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 },
    );
  }

  const response: Record<string, unknown> = { status };
  if (body.debug === true) response.diagnostics = diagnostics;

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
