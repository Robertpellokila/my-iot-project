export async function onRequestPost(context) {
  try {
    const request = context.request;
    const env = context.env;

    // ==========================================
    // 1. CHECK DEVICE API KEY
    // ==========================================

    const deviceKey = request.headers.get("X-Device-Key");

    if (!deviceKey) {
      return jsonResponse(
        {
          success: false,
          message: "Missing device key",
        },
        401
      );
    }

    if (deviceKey !== env.DEVICE_API_KEY) {
      return jsonResponse(
        {
          success: false,
          message: "Invalid device key",
        },
        401
      );
    }

    // ==========================================
    // 2. READ REQUEST BODY
    // ==========================================

    const body = await request.json();

    const uid = body.uid;
    const deviceId = body.device_id;

    // ==========================================
    // 3. VALIDATION
    // ==========================================

    if (!uid) {
      return jsonResponse(
        {
          success: false,
          message: "UID is required",
        },
        400
      );
    }

    if (!deviceId) {
      return jsonResponse(
        {
          success: false,
          message: "Device ID is required",
        },
        400
      );
    }

    // ==========================================
    // 4. NORMALIZE UID
    // ==========================================

    const normalizedUid = String(uid)
      .replace(/[^a-fA-F0-9]/g, "")
      .toUpperCase();

    if (!normalizedUid) {
      return jsonResponse(
        {
          success: false,
          message: "Invalid UID",
        },
        400
      );
    }

    // ==========================================
    // 5. INSERT TO SUPABASE
    // ==========================================

    const supabaseUrl = env.SUPABASE_URL;
    const supabaseKey = env.SUPABASE_SECRET_KEY;

    if (!supabaseUrl || !supabaseKey) {
      return jsonResponse(
        {
          success: false,
          message: "Supabase environment variables are not configured",
        },
        500
      );
    }

    const response = await fetch(
      `${supabaseUrl}/rest/v1/scan_events`,
      {
        method: "POST",

        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },

        body: JSON.stringify({
          uid: normalizedUid,
          device_id: deviceId,
        }),
      }
    );

    const result = await response.text();

    if (!response.ok) {
      console.error("Supabase error:", result);

      return jsonResponse(
        {
          success: false,
          message: "Failed to save scan event",
          error: result,
        },
        500
      );
    }

    // ==========================================
    // 6. SUCCESS
    // ==========================================

    return jsonResponse(
      {
        success: true,
        message: "RFID scan saved successfully",
        data: JSON.parse(result),
      },
      201
    );
  } catch (error) {
    console.error("Function error:", error);

    return jsonResponse(
      {
        success: false,
        message: "Internal server error",
      },
      500
    );
  }
}


// ==========================================
// JSON RESPONSE HELPER
// ==========================================

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,

    headers: {
      "Content-Type": "application/json",
    },
  });
}

// ==========================================
// OPTIONS HELPER FOR CORS PREFLIGHT
// ==========================================

export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, X-Device-Key",
    },
  });
}