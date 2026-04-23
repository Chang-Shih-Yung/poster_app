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
// Model: Falconsai/nsfw_image_detection — open-source, Apache 2.0,
// returns 5 labels with scores: porn / hentai / sexy / drawing /
// neutral. Same five-class scheme as NSFWJS.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const HF_MODEL = "Falconsai/nsfw_image_detection";
const HF_URL = `https://api-inference.huggingface.co/models/${HF_MODEL}`;

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
  const score = (k: string) =>
    labels.find((l) => l.label.toLowerCase() === k)?.score ?? 0;

  // Hard reject: porn or hentai > 0.7.
  if (score("porn") > 0.7 || score("hentai") > 0.7) return "rejected";

  // Soft flag for admin: explicit "sexy" or borderline porn/hentai.
  if (
    score("sexy") > 0.5 ||
    score("porn") > 0.4 ||
    score("hentai") > 0.4
  ) {
    return "pending_review";
  }

  return "ok";
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), {
      status: 405,
    });
  }
  let body: Body;
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

  try {
    // Fetch the uploaded image and forward to HF inference.
    const imgRes = await fetch(body.image_url);
    if (!imgRes.ok) throw new Error(`image fetch ${imgRes.status}`);
    const bytes = new Uint8Array(await imgRes.arrayBuffer());

    const hfRes = await fetch(HF_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("HF_API_TOKEN")}`,
        "Content-Type": "application/octet-stream",
      },
      body: bytes,
    });

    if (!hfRes.ok) {
      // Model load may take a few seconds on cold start — HF returns 503
      // with `estimated_time`. Treat as transient: leave status 'ok'
      // and let the user-report path catch real violators.
      console.warn(`HF returned ${hfRes.status}, defaulting to ok`);
    } else {
      const labels = (await hfRes.json()) as HFLabel[];
      status = classify(labels);
    }
  } catch (err) {
    // Network error / timeout. Don't block the upload — fail open.
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

  return new Response(JSON.stringify({ status }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
