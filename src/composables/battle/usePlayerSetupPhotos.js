import { computed, onUnmounted, reactive } from "vue";
import { compressImageFile } from "../../lib/compressImage.js";
import { supabase } from "../../lib/supabase.js";

const emptyPhoto = () => ({
  file: null,
  preview: "",
  processing: false,
  error: "",
  uploadUrl: "",
  uploadOwner: "",
  revision: 0,
});

export function usePlayerSetupPhotos() {
  const photos = reactive({ p1: emptyPhoto(), p2: emptyPhoto() });
  const processingPhotos = computed(() => photos.p1.processing || photos.p2.processing);
  let disposed = false;

  const clearPhoto = (player) => {
    const photo = photos[player];
    if (photo.preview) URL.revokeObjectURL(photo.preview);
    Object.assign(photo, emptyPhoto(), { revision: photo.revision + 1 });
  };

  const selectPhoto = async (player, file) => {
    if (!file) return;
    const photo = photos[player];
    const revision = ++photo.revision;
    photo.processing = true;
    photo.error = "";
    try {
      const compressed = await compressImageFile(file, {
        maxSourceBytes: 5 * 1024 * 1024,
        maxOutputBytes: 1024 * 1024,
        maxDimension: 800,
      });
      if (disposed || revision !== photo.revision) return;
      if (photo.preview) URL.revokeObjectURL(photo.preview);
      photo.file = compressed;
      photo.preview = URL.createObjectURL(compressed);
      photo.uploadUrl = "";
      photo.uploadOwner = "";
    } catch (error) {
      // Keep the previous valid photo if its replacement cannot be processed.
      if (!disposed && revision === photo.revision) {
        photo.error = error?.message ?? "Foto tidak dapat diproses. Pilih foto lain.";
      }
    } finally {
      if (!disposed && revision === photo.revision) photo.processing = false;
    }
  };

  const uploadPhotos = async (userId) => {
    const result = {};
    for (const [index, player] of ["p1", "p2"].entries()) {
      const photo = photos[player];
      if (!photo.file) continue;
      photo.error = "";
      if (!photo.uploadUrl || photo.uploadOwner !== userId) {
        try {
          const path = `player-avatars/${userId}/${crypto.randomUUID()}.webp`;
          const { error } = await supabase.storage.from("card-images").upload(path, photo.file, {
            cacheControl: "31536000",
            contentType: "image/webp",
            upsert: false,
          });
          if (error) throw error;
          // Reuse an upload when creation is retried after a later failure.
          photo.uploadUrl = supabase.storage.from("card-images").getPublicUrl(path).data.publicUrl;
          photo.uploadOwner = userId;
        } catch {
          photo.error = `Foto Player ${index + 1} belum berhasil diunggah. Coba lagi atau hapus foto untuk memakai avatar bawaan.`;
          throw new Error(photo.error);
        }
      }
      result[`player${index + 1}_avatar_url`] = photo.uploadUrl;
    }
    return result;
  };

  const clearPhotos = () => {
    clearPhoto("p1");
    clearPhoto("p2");
  };
  onUnmounted(() => {
    disposed = true;
    clearPhotos();
  });

  return { photos, processingPhotos, selectPhoto, clearPhoto, clearPhotos, uploadPhotos };
}
