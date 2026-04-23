// ═══════════════════════════════════════════════════════════════════
// poster-blurhash — compute BlurHash for an uploaded poster.
// ═══════════════════════════════════════════════════════════════════
//
// Triggered by the front-end RIGHT AFTER `posters` row insert (manual
// invoke). Future: hook to a storage trigger so it runs automatically.
//
// Input  POST body: { "poster_id": "uuid", "image_url": "https://..." }
// Output 200: { "blurhash": "L6P..." }   (also writes to posters.blurhash)
//        400: { "error": "..." }
//
// Free / open-source — uses the blurhash-deno port. ~50ms per image
// at 320x180 decode resolution; service-role write back is one
// statement.
//
// Deploy:
//   supabase functions deploy poster-blurhash --no-verify-jwt
//   (no-verify-jwt because the front-end calls this with the anon
//    key after a successful insert; the body itself is the auth.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { encode as encodeBlurhash } from "https://esm.sh/blurhash@2.0.5";
import { decode as decodeJpeg } from "https://esm.sh/jpeg-js@0.4.4";
import { PNG } from "https://esm.sh/pngjs@7.0.0";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

interface Body {
  poster_id: string;
  image_url: string;
}

async function rgbaFor(imageUrl: string): Promise<{
  data: Uint8ClampedArray;
  width: number;
  height: number;
}> {
  const res = await fetch(imageUrl);
  if (!res.ok) {
    throw new Error(`fetch ${res.status}`);
  }
  const buf = new Uint8Array(await res.arrayBuffer());
  const ctype = (res.headers.get("content-type") ?? "").toLowerCase();

  if (ctype.includes("png")) {
    const png = PNG.sync.read(Buffer.from(buf));
    return {
      data: new Uint8ClampedArray(png.data),
      width: png.width,
      height: png.height,
    };
  }
  // Default: JPEG (covers our compressed posters).
  const jpeg = decodeJpeg(buf, { useTArray: true });
  return {
    data: new Uint8ClampedArray(jpeg.data),
    width: jpeg.width,
    height: jpeg.height,
  };
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
  if (!body.poster_id || !body.image_url) {
    return new Response(
      JSON.stringify({ error: "poster_id + image_url required" }),
      { status: 400 },
    );
  }

  try {
    const { data, width, height } = await rgbaFor(body.image_url);
    // 4×3 components — Wolt's recommended balance of fidelity vs hash
    // length. Output is 28-30 chars.
    const hash = encodeBlurhash(data, width, height, 4, 3);

    const { error } = await supabase
      .from("posters")
      .update({ blurhash: hash })
      .eq("id", body.poster_id);
    if (error) throw error;

    return new Response(JSON.stringify({ blurhash: hash }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500 },
    );
  }
});
