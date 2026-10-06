const TYPE_ALIASES = Object.freeze({
  electric: "thunder",
  ice: "water",
  grass: "forest",
  wind: "thunder",
  lightning: "thunder",
  nature: "forest",
  holy: "light",
  warrior: "knight",
  shadow: "dark",
});

const TCG_TYPES = new Set([
  "knight",
  "fire",
  "water",
  "forest",
  "thunder",
  "light",
  "dark",
]);

export const normalizeTcgType = (value) => {
  const type = String(value ?? "").trim().toLowerCase();
  const normalized = TYPE_ALIASES[type] ?? type;
  return TCG_TYPES.has(normalized) ? normalized : null;
};

export const getTcgComboTypeKey = (values = []) => {
  const normalized = values.map(normalizeTcgType);
  if (normalized.some((value) => !value)) return null;
  return normalized.sort().join("+");
};

export const formatTcgType = (value) => {
  const normalized = normalizeTcgType(value);
  const label = normalized ?? String(value ?? "").trim().toLowerCase();
  if (!label) return "Unknown";
  return label.charAt(0).toUpperCase() + label.slice(1);
};
