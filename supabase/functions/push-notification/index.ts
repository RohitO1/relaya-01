// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function signJwt(serviceAccount: any): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64url(new TextEncoder().encode(JSON.stringify(header)));
  const encodedClaimSet = base64url(new TextEncoder().encode(JSON.stringify(claimSet)));
  const stringToSign = `${encodedHeader}.${encodedClaimSet}`;

  // Parse PEM key
  const pem = serviceAccount.private_key;
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  
  const startIndex = pem.indexOf(pemHeader);
  const endIndex = pem.indexOf(pemFooter);
  if (startIndex === -1 || endIndex === -1) {
    throw new Error("Invalid private key format in service account.");
  }
  
  const pemContents = pem
    .substring(startIndex + pemHeader.length, endIndex)
    .replace(/\s/g, "");
  
  // Base64 decode to binary DER
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(stringToSign)
  );

  const encodedSignature = base64url(new Uint8Array(signature));
  return `${stringToSign}.${encodedSignature}`;
}

async function getAccessToken(serviceAccount: any): Promise<string> {
  const jwt = await signJwt(serviceAccount);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await response.json();
  if (data.error) {
    throw new Error(`Token fetch failed: ${data.error_description || data.error}`);
  }
  return data.access_token;
}

// Keep a cached access token and its expiration time in memory
let cachedAccessToken: string | null = null;
let tokenExpiryTime = 0;

async function getOrRefreshToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // Refresh token 5 minutes before it actually expires
  if (cachedAccessToken && now < tokenExpiryTime - 300) {
    return cachedAccessToken;
  }
  console.log("Fetching new Google OAuth2 Access Token...");
  const token = await getAccessToken(serviceAccount);
  cachedAccessToken = token;
  tokenExpiryTime = now + 3600;
  return token;
}

Deno.serve(async (req) => {
  try {
    // Webhook payload from Supabase
    const payload = await req.json();
    console.log("Webhook payload received:", payload);

    if (payload.type !== "INSERT" || payload.table !== "notifications") {
      return new Response(JSON.stringify({ message: "Ignored. Not a notification insert." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    const notificationRecord = payload.record;
    if (!notificationRecord || !notificationRecord.user_id) {
      throw new Error("Invalid notification record.");
    }

    // 2. Initialize Supabase Client to fetch the FCM token
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment variables are missing.");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Fetch the target user's FCM token
    const { data: tokenData, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .eq("user_id", notificationRecord.user_id)
      .single();

    if (tokenError) {
      console.warn(`Could not find FCM token for user ${notificationRecord.user_id}:`, tokenError.message);
      return new Response(JSON.stringify({ message: "No FCM token found for user." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    const fcmToken = tokenData.fcm_token;
    if (!fcmToken) {
      console.log(`FCM token is empty for user ${notificationRecord.user_id}`);
      return new Response(JSON.stringify({ message: "Empty FCM token." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 4. Retrieve service account details from env
    const serviceAccountKeyStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountKeyStr) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT environment variable is missing.");
    }
    const serviceAccount = JSON.parse(serviceAccountKeyStr);

    // 5. Get access token (cached or fresh)
    const accessToken = await getOrRefreshToken(serviceAccount);

    // 6. Construct FCM v1 message payload
    const fcmPayload = {
      message: {
        token: fcmToken,
        notification: {
          title: notificationRecord.title || "Meetra Notification",
          body: notificationRecord.body || "",
        },
        data: {
          type: notificationRecord.type || "system",
          payload: JSON.stringify(notificationRecord.payload || {}),
        },
        android: {
          priority: "HIGH",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      },
    };

    // 7. Send push notification directly via REST API
    const projectId = serviceAccount.project_id;
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    const fcmResult = await fcmResponse.json();
    if (!fcmResponse.ok) {
      throw new Error(`FCM API returned error: ${JSON.stringify(fcmResult)}`);
    }

    console.log(`Successfully sent message (ID: ${fcmResult.name}) to user ${notificationRecord.user_id}`);

    return new Response(JSON.stringify({ success: true, messageId: fcmResult.name }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error("Error processing webhook:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
