const TECHNICAL_ERROR_PATTERN =
  /(?:violates\s+.{0,100}\sconstraint|new row for relation|insert or update on table|duplicate key value|row-level security|permission denied|SQLSTATE|PGRST\d+|PostgreSQL|PostgREST|schema cache|could not find.*function|function .* does not exist|relation .* does not exist|column .* does not exist|invalid input syntax|foreign key|not-null constraint|null value in column|operator does not exist|JWT expired|invalid JWT|failed to fetch|networkerror|typeerror:|cannot read properties|deadlock detected|could not serialize access|canceling statement|internal server error|database error|rpc error|query failed|connection terminated|\bpublic\.[a-z_]+\b)/i;

const DEFAULT_SAFE_MESSAGE =
  "Aksi belum dapat diproses. Perbarui battle lalu coba lagi. Jika masalah berulang, hubungi admin.";

export const safePlayerMessage = (value, fallback = DEFAULT_SAFE_MESSAGE) => {
  const message = String(value ?? "").trim();

  if (!message || message.length > 240 || TECHNICAL_ERROR_PATTERN.test(message)) {
    return fallback;
  }

  return message.replace(/\bAP\b/gi, "poin giliran");
};

export const playerErrorMessage = (error, fallback = DEFAULT_SAFE_MESSAGE) => {
  const message = [error?.message, error?.details, error?.hint]
    .filter(Boolean)
    .join(" ");
  const code = String(error?.code ?? "");

  if (/battle_sessions_winner_check/i.test(message)) {
    return "Serangan belum berhasil disimpan. Perbarui battle lalu coba lagi.";
  }

  if (/^(?:[0-9A-Z]{5}|PGRST\d+)$/i.test(code)) {
    return fallback;
  }

  return safePlayerMessage(message, fallback);
};
