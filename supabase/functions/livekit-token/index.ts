// supabase/functions/livekit-token/index.ts
// Deploy with: npx supabase functions deploy livekit-token
// Set secrets: npx supabase secrets set LIVEKIT_API_KEY=xxx LIVEKIT_API_SECRET=xxx

// @ts-ignore: Deno environment variable bypass for standard TS
declare const Deno: any;

// @ts-ignore: npm specifier bypass for standard TS
import { AccessToken } from "npm:livekit-server-sdk@^2.0.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed. Must be a POST request." }), { 
        status: 405, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    const body = await req.json();
    const { roomName, userId, userName, avatarUrl } = body;

    if (!roomName || !userId) {
      return new Response(
        JSON.stringify({ error: "roomName and userId are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");

    if (!apiKey || !apiSecret) {
      return new Response(
        JSON.stringify({ error: "LiveKit credentials not configured on server" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create JWT token
    const at = new AccessToken(apiKey, apiSecret, {
      identity: userId,       // Use Supabase user ID as identity
      name: userName ?? "User",
      metadata: JSON.stringify({ avatarUrl: avatarUrl ?? "" }),
      ttl: "6h",              // Token valid for 6 hours
    });

    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,       // Can send audio
      canSubscribe: true,     // Can receive audio from others
      canPublishData: true,   // Can send data messages
    });

    const token = await at.toJwt();

    return new Response(
      JSON.stringify({ token }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
