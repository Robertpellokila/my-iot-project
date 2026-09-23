import { supabase } from "../lib/supabase";


/**
 * Normalize UID
 *
 * Example:
 *
 * "a1 b2 c3 d4"
 *
 * becomes:
 *
 * "A1B2C3D4"
 */
export function normalizeUid(uid) {
  return uid
    .replace(/\s+/g, "")
    .replace(/:/g, "")
    .replace(/-/g, "")
    .toUpperCase();
}


/**
 * Convert UI card type
 * into database enum value.
 */
export function normalizeCardType(type) {
  const typeMap = {
    "RFID Card": "rfid_card",
    "RFID Tag": "rfid_tag",
    "e-KTP": "e_ktp",
    "Other": "other",
  };

  return typeMap[type] || type;
}


/**
 * Convert database type
 * back to UI label.
 */
export function formatCardType(type) {
  const typeMap = {
    rfid_card: "RFID Card",
    rfid_tag: "RFID Tag",
    e_ktp: "e-KTP",
    other: "Other",
  };

  return typeMap[type] || type;
}


/**
 * GET ALL RFID
 */
export async function getRfidCards() {
  const {
    data,
    error,
  } = await supabase
    .from("rfid_cards")
    .select(`
      id,
      uid,
      card_type,
      label,
      is_active,
      created_at,
      updated_at,
      owner_id,
      profiles (
        id,
        full_name
      )
    `)
    .order("created_at", {
      ascending: false,
    });

  if (error) {
    throw error;
  }

  return data || [];
}


/**
 * GET RFID BY ID
 */
export async function getRfidById(id) {
  const {
    data,
    error,
  } = await supabase
    .from("rfid_cards")
    .select(`
      id,
      uid,
      card_type,
      label,
      is_active,
      created_at,
      updated_at,
      owner_id,
      profiles (
        id,
        full_name
      )
    `)
    .eq("id", id)
    .single();

  if (error) {
    throw error;
  }

  return data;
}


/**
 * CREATE RFID
 */
export async function createRfid({
  uid,
  ownerId = null,
  cardType = "rfid_card",
  label = null,
  isActive = true,
}) {
  const normalizedUid =
    normalizeUid(uid);

  if (!normalizedUid) {
    throw new Error(
      "UID RFID tidak boleh kosong."
    );
  }

  const {
    data: existing,
    error: existingError,
  } = await supabase
    .from("rfid_cards")
    .select("id")
    .eq("uid", normalizedUid)
    .maybeSingle();

  if (existingError) {
    throw existingError;
  }

  if (existing) {
    throw new Error(
      "UID RFID sudah terdaftar."
    );
  }

  const {
    data,
    error,
  } = await supabase
    .from("rfid_cards")
    .insert({
      uid: normalizedUid,
      owner_id: ownerId,
      card_type:
        normalizeCardType(cardType),
      label: label?.trim() || null,
      is_active: isActive,
    })
    .select(`
      id,
      uid,
      card_type,
      label,
      is_active,
      created_at,
      updated_at,
      owner_id,
      profiles (
        id,
        full_name
      )
    `)
    .single();

  if (error) {
    if (error.code === "23505") {
      throw new Error(
        "UID RFID sudah terdaftar."
      );
    }

    throw error;
  }

  return data;
}


/**
 * UPDATE RFID
 */
export async function updateRfid(
  id,
  {
    uid,
    ownerId = null,
    cardType = "rfid_card",
    label = null,
    isActive = true,
  }
) {
  const normalizedUid =
    normalizeUid(uid);

  if (!normalizedUid) {
    throw new Error(
      "UID RFID tidak boleh kosong."
    );
  }

  const {
    data: duplicate,
    error: duplicateError,
  } = await supabase
    .from("rfid_cards")
    .select("id")
    .eq("uid", normalizedUid)
    .neq("id", id)
    .maybeSingle();

  if (duplicateError) {
    throw duplicateError;
  }

  if (duplicate) {
    throw new Error(
      "UID RFID sudah digunakan oleh RFID lain."
    );
  }

  const {
    data,
    error,
  } = await supabase
    .from("rfid_cards")
    .update({
      uid: normalizedUid,
      owner_id: ownerId,
      card_type:
        normalizeCardType(cardType),
      label: label?.trim() || null,
      is_active: isActive,
    })
    .eq("id", id)
    .select(`
      id,
      uid,
      card_type,
      label,
      is_active,
      created_at,
      updated_at,
      owner_id,
      profiles (
        id,
        full_name
      )
    `)
    .single();

  if (error) {
    if (error.code === "23505") {
      throw new Error(
        "UID RFID sudah terdaftar."
      );
    }

    throw error;
  }

  return data;
}


/**
 * DELETE RFID
 */
export async function deleteRfid(id) {
  const {
    error,
  } = await supabase
    .from("rfid_cards")
    .delete()
    .eq("id", id);

  if (error) {
    throw error;
  }

  return true;
}


/**
 * GET PROFILE OPTIONS
 *
 * Dipakai untuk memilih owner.
 */
export async function getProfiles() {
  const {
    data,
    error,
  } = await supabase
    .from("profiles")
    .select(`
      id,
      full_name,
      role
    `)
    .order("full_name");

  if (error) {
    throw error;
  }

  return data || [];
}


/**
 * GET RFID STATISTICS
 */
export async function getRfidStats() {
  const {
    count: total,
    error: totalError,
  } = await supabase
    .from("rfid_cards")
    .select("*", {
      count: "exact",
      head: true,
    });

  if (totalError) {
    throw totalError;
  }

  const {
    count: active,
    error: activeError,
  } = await supabase
    .from("rfid_cards")
    .select("*", {
      count: "exact",
      head: true,
    })
    .eq("is_active", true);

  if (activeError) {
    throw activeError;
  }

  const {
    count: inactive,
    error: inactiveError,
  } = await supabase
    .from("rfid_cards")
    .select("*", {
      count: "exact",
      head: true,
    })
    .eq("is_active", false);

  if (inactiveError) {
    throw inactiveError;
  }

  const {
    count: scans,
    error: scansError,
  } = await supabase
    .from("scan_events")
    .select("*", {
      count: "exact",
      head: true,
    });

  if (scansError) {
    throw scansError;
  }

  return {
    total: total || 0,
    active: active || 0,
    inactive: inactive || 0,
    scans: scans || 0,
  };
}