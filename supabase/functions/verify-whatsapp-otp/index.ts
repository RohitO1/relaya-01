// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone, otp } = await req.json();

    if (!phone || !otp) {
      return new Response(
        JSON.stringify({ success: false, error: "Phone number and OTP code are required." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const cleanPhone = phone.trim();
    const cleanOtp = otp.trim();

    // 1. Initialize Supabase Service Role Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment variables are missing.");
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Query OTP from `whatsapp_otps` table
    const { data: otpData, error: dbError } = await supabase
      .from("whatsapp_otps")
      .select("*")
      .eq("phone", cleanPhone)
      .maybeSingle();

    if (dbError) {
      console.error("Database query error:", dbError.message);
      throw new Error(`Failed to query OTP from database: ${dbError.message}`);
    }

    if (!otpData) {
      return new Response(
        JSON.stringify({ success: false, error: "No OTP request found for this phone number." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // 3. Verify OTP code and expiration
    const isCodeValid = otpData.otp_code === cleanOtp;
    const isNotExpired = new Date(otpData.expires_at) > new Date();

    if (!isCodeValid || !isNotExpired) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: !isCodeValid ? "Invalid OTP code entered." : "OTP code has expired. Please request a new one." 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // OTP is valid! Delete the OTP record so it cannot be verified again (single-use token security)
    const { error: deleteError } = await supabase
      .from("whatsapp_otps")
      .delete()
      .eq("phone", cleanPhone);

    if (deleteError) {
      console.warn("Warning: failed to delete used OTP record:", deleteError.message);
    }

    // 4. Generate Synthetic Credentials
    const phoneDigits = cleanPhone.replace(/\D/g, "");
    const syntheticEmail = `phone_${phoneDigits}@relaya.app`;

    // Calculate a secure deterministic password using SHA-256
    const secretKey = Deno.env.get("JWT_SECRET") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "relaya_default_jwt_secret_999";
    const dataToHash = new TextEncoder().encode(cleanPhone + secretKey);
    const hashBuffer = await crypto.subtle.digest("SHA-256", dataToHash);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
    const syntheticPassword = `phone_auth_${hashHex.substring(0, 32)}`;

    // 5. Ensure user exists in Supabase Auth
    console.log(`Checking/Creating Supabase auth user for: ${syntheticEmail}`);
    const { data: newUser, error: signUpError } = await supabase.auth.admin.createUser({
      email: syntheticEmail,
      password: syntheticPassword,
      email_confirm: true,
      user_metadata: {
        phone_number: cleanPhone,
        provider: "whatsapp_otp"
      }
    });

    if (signUpError) {
      // Check if user already exists
      const isAlreadyRegistered = signUpError.message.toLowerCase().includes("already registered") || 
                                  signUpError.message.toLowerCase().includes("already been registered") ||
                                  signUpError.status === 422;

      if (!isAlreadyRegistered) {
        console.error("Supabase Admin Auth error:", signUpError.message);
        throw new Error(`Failed to provision user: ${signUpError.message}`);
      } else {
        console.log(`User ${syntheticEmail} already exists. Returning login credentials.`);
      }
    } else {
      console.log(`Successfully provisioned new user: ${newUser.user.id}`);
    }

    // 6. Return the synthetic credentials to client
    return new Response(
      JSON.stringify({ 
        success: true, 
        email: syntheticEmail, 
        password: syntheticPassword 
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error("Error in verify-whatsapp-otp:", err.message);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
