// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Known test numbers to bypass WhatsApp API sending
function isTestPhoneNumber(phone: string): boolean {
  const cleanPhone = phone.replace(/\D/g, "");
  const knownTestNumbers = [
    "16505553434",
    "919876543210",
    "911234567890",
    "919999999999",
    "918888888888",
    "917777777777",
    "910000000000",
    "1234567890",
    "917429831589",
    "7429831589",
    "917905761080",
    "7905761080",
  ];
  return knownTestNumbers.includes(cleanPhone) || cleanPhone.includes("555");
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone } = await req.json();
    if (!phone) {
      return new Response(
        JSON.stringify({ success: false, error: "Phone number is required." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const cleanPhone = phone.trim();

    // 1. Initialize Supabase Service Role Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment variables are missing.");
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Generate OTP Code (6 digits)
    let otpCode = "";
    if (isTestPhoneNumber(cleanPhone)) {
      otpCode = "123456"; // Standard mock code for testing
      console.log(`[Test Mode] Mock OTP 123456 generated for test phone: ${cleanPhone}`);
    } else {
      otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    }

    // 3. Save to database table `whatsapp_otps`
    // Expires in 5 minutes
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
    const { error: dbError } = await supabase
      .from("whatsapp_otps")
      .upsert(
        {
          phone: cleanPhone,
          otp_code: otpCode,
          expires_at: expiresAt,
          created_at: new Date().toISOString(),
        },
        { onConflict: "phone" }
      );

    if (dbError) {
      console.error("Database save error:", dbError.message);
      throw new Error(`Failed to save OTP to database: ${dbError.message}`);
    }

    // If it's a test phone, return success directly without sending WhatsApp API call
    if (isTestPhoneNumber(cleanPhone)) {
      return new Response(
        JSON.stringify({ success: true, message: "Mock OTP sent successfully." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // 4. Retrieve Meta WhatsApp API Keys
    const waPhoneId = Deno.env.get("META_WHATSAPP_PHONE_NUMBER_ID") || Deno.env.get("META_PHONE_NUMBER_ID");
    const waToken = Deno.env.get("META_WHATSAPP_ACCESS_TOKEN") || Deno.env.get("META_WHATSAPP_TOKEN");
    const waTemplate = Deno.env.get("META_WHATSAPP_TEMPLATE_NAME") || Deno.env.get("META_TEMPLATE_NAME") || "auth_otp";
    const waTemplateLang = Deno.env.get("META_WHATSAPP_TEMPLATE_LANG") || Deno.env.get("META_TEMPLATE_LANG") || "en";
    const waHasButton = (Deno.env.get("META_TEMPLATE_HAS_BUTTON") || "false").toLowerCase() === "true";

    // Development fallback: if keys are not set, log OTP to console and return success
    if (!waPhoneId || !waToken) {
      console.warn("************************************************************************");
      console.warn(`[DEV FALLBACK] Meta WhatsApp credentials are not configured!`);
      console.warn(`Generated OTP: ${otpCode} for phone: ${cleanPhone}`);
      console.warn("Please configure META_PHONE_NUMBER_ID and META_WHATSAPP_TOKEN in Supabase Secrets.");
      console.warn("************************************************************************");

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: "OTP generated (Dev Mode: logged to console).",
          devMode: true 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // 5. Send OTP via Meta WhatsApp Cloud API
    const cleanDigits = cleanPhone.replace("+", ""); // Recipient number should be digits only (e.g. 919999999999)
    const url = `https://graph.facebook.com/v20.0/${waPhoneId}/messages`;
    
    // Build components array dynamically based on template type
    const noParamTemplates = ["hello_world"];
    const isAuthTemplate = (Deno.env.get("META_TEMPLATE_IS_AUTH") || "false").toLowerCase() === "true";
    const components: Record<string, unknown>[] = [];

    if (!noParamTemplates.includes(waTemplate)) {
      if (isAuthTemplate) {
        // Authentication templates use a single button component with copy_code sub_type
        // The OTP is passed as the button parameter ({{1}} in the button, not the body)
        components.push({
          type: "button",
          sub_type: "url",
          index: "0",
          parameters: [
            {
              type: "text",
              text: otpCode,
            },
          ],
        });
      } else {
        // Standard utility templates use a body component with {{1}}
        components.push({
          type: "body",
          parameters: [
            {
              type: "text",
              text: otpCode,
            },
          ],
        });

        if (waHasButton) {
          components.push({
            type: "button",
            sub_type: "url",
            index: "0",
            parameters: [
              {
                type: "text",
                text: otpCode,
              },
            ],
          });
        }
      }
    }

    // Standard payload structure for WhatsApp OTP templates
    const payload: Record<string, unknown> = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: cleanDigits,
      type: "template",
      template: {
        name: waTemplate,
        language: {
          code: waTemplateLang,
        },
        ...(components.length > 0 ? { components } : {}),
      },
    };

    console.log(`Sending Meta WhatsApp message to +${cleanDigits} using template "${waTemplate}" (lang: ${waTemplateLang})...`);
    console.log(`Payload: ${JSON.stringify(payload)}`);
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${waToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const result = await response.json();

    if (!response.ok) {
      console.warn("Template message failed, trying plain text fallback:", JSON.stringify(result));
      
      // Fallback: Send as plain text message (works during 24-hour customer service window)
      const textPayload = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: cleanDigits,
        type: "text",
        text: {
          preview_url: false,
          body: `Your Relaya verification code is: ${otpCode}\n\nThis code expires in 5 minutes. Do not share it with anyone.`,
        },
      };

      console.log("Attempting plain text fallback...");
      const textResponse = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${waToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(textPayload),
      });

      const textResult = await textResponse.json();

      if (!textResponse.ok) {
        console.error("Plain text fallback also failed:", JSON.stringify(textResult));
        throw new Error(`Meta API error: ${result.error?.message || "Unknown error"}`);
      }

      console.log(`Successfully sent OTP via text fallback to +${cleanDigits}. Message ID: ${textResult.messages?.[0]?.id}`);
    } else {
      console.log(`Successfully sent OTP to +${cleanDigits}. Message ID: ${result.messages?.[0]?.id}`);
    }

    return new Response(
      JSON.stringify({ success: true, message: "OTP sent successfully." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error("Error in send-whatsapp-otp:", err.message);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
