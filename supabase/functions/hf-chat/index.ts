import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Supabase webhook payload interface
interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: {
    id: string;
    sender_id: string;
    receiver_id: string;
    text: string;
    is_image: boolean;
    created_at: string;
  };
  schema: string;
}

const HF_API_URL = "https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium";
// The bot's distinct UUID mimicking our flutter app structure
const BOT_UUID = '00000000-0000-0000-0000-000000000000';

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    // Only process insertions directed AT the bot, not sent BY the bot
    if (payload.type === 'INSERT' && payload.record.receiver_id === BOT_UUID && payload.record.sender_id !== BOT_UUID) {
      
      const hfToken = Deno.env.get("HF_API_KEY");
      if (!hfToken) {
          throw new Error("Missing HF_API_KEY environment variable. Have you set it in 'supabase secrets set HF_API_KEY=...'?");
      }

      // Query HuggingFace
      const hfResponse = await fetch(HF_API_URL, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${hfToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ inputs: payload.record.text }),
      });

      if (!hfResponse.ok) {
         throw new Error(`HF API error: ${hfResponse.status}`);
      }
      
      const hfData = await hfResponse.json();
      let aiText = "I couldn't process that.";
      if (Array.isArray(hfData) && hfData.length > 0 && hfData[0].generated_text) {
          aiText = hfData[0].generated_text.replace(payload.record.text, '').trim();
      }

      // We need to insert the response back into the DB.
      // Easiest is to use the Supabase JS client inside the Edge Function or standard REST.
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

      const insertRes = await fetch(`${supabaseUrl}/rest/v1/messages`, {
        method: 'POST',
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
          'Content-Type': 'application/json',
          'Preferences': 'return=minimal'
        },
        body: JSON.stringify({
          sender_id: BOT_UUID,
          receiver_id: payload.record.sender_id,
          text: aiText,
          is_image: false,
        })
      });

      if (!insertRes.ok) {
         throw new Error(`Failed to insert reply into DB: ${await insertRes.text()}`);
      }

      return new Response(JSON.stringify({ success: true, ai_response: aiText }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ignored: true }), { headers: { "Content-Type": "application/json" } });

  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
