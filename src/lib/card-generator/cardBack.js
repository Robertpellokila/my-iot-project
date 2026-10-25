// A single approved full-card image, shared by all rarities and export formats.
export const FIXED_BACK = Object.freeze({
  id: 'timedoor-academy-green-tbc-v1',
  url: '/images/tbc-back.png',
  sha256: 'bbb872f65117aa57bef346a4953d351c0762cb1ee6d425f16a55ac24a70fd79e',
  width: 1024, height: 1536,
});
export const fixedBackAvailable = () => /^[a-f0-9]{64}$/.test(FIXED_BACK.sha256);
