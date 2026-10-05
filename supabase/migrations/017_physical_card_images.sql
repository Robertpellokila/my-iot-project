-- Store an optional finished physical-card front separately from the cover artwork.
ALTER TABLE public.game_cards
  ADD COLUMN IF NOT EXISTS physical_card_image_url text;
