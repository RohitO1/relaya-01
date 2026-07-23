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
    const { idToken } = await req.json();

    if (!idToken) {
      return new Response(
        JSON.stringify({ success: false, error: "Firebase ID token is required." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // 1. Fetch Firebase API Key
    const firebaseApiKey = Deno.env.get("FIREBASE_API_KEY") || "AIzaSyDWD5TXC2wetAqhULay7ziB8eJ0pufFWw4";

    // 2. Verify token via Google Identity REST API
    console.log("Verifying ID token with Firebase Auth API...");
    const firebaseVerifyUrl = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${firebaseApiKey}`;
    const verifyRes = await fetch(firebaseVerifyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    });

    const verifyData = await verifyRes.json();

    if (!verifyRes.ok || !verifyData.users || verifyData.users.length === 0) {
      const errMsg = verifyData.error?.message || "Invalid or expired Firebase ID token.";
      console.error("Firebase token verification failed:", errMsg);
      return new Response(
        JSON.stringify({ success: false, error: errMsg }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const firebaseUser = verifyData.users[0];
    const rawPhone = firebaseUser.phoneNumber;

    if (!rawPhone) {
      return new Response(
        JSON.stringify({ success: false, error: "No verified phone number found in the token." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const cleanPhone = rawPhone.trim();
    console.log(`Token verified successfully. Phone number: ${cleanPhone}`);

    // 3. Initialize Supabase Service Role Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment variables are missing.");
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 4. Generate Synthetic Credentials (mirroring verify-whatsapp-otp logic)
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
        provider: "firebase_phone_auth"
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
    console.error("Error in verify-firebase-token:", err.message);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
