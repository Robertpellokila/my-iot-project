const MAX_SOURCE_BYTES = 10 * 1024 * 1024;
const MAX_OUTPUT_BYTES = 1024 * 1024;
const ACCEPTED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

const toWebpBlob = (canvas, quality) => new Promise((resolve, reject) => {
  canvas.toBlob((blob) => {
    if (!blob) {
      reject(new Error("Browser gagal memproses gambar."));
      return;
    }
    if (blob.type !== "image/webp") {
      reject(new Error("Browser ini tidak mendukung ekspor WebP."));
      return;
    }
    resolve(blob);
  }, "image/webp", quality);
});

/**
 * Resize and convert an uploaded raster image to WebP in the browser.
 * Transparency is preserved for PNG/WebP sources.
 */
export async function compressImageFile(file, {
  maxSourceBytes = MAX_SOURCE_BYTES,
  maxOutputBytes = MAX_OUTPUT_BYTES,
  maxDimension = 1800,
} = {}) {
  if (!file || !ACCEPTED_IMAGE_TYPES.has(file.type)) {
    throw new Error("Pilih gambar JPG, PNG, atau WebP. GIF dan SVG belum didukung.");
  }
  if (file.size > maxSourceBytes) {
    throw new Error(`Ukuran gambar sebelum kompres maksimal ${Math.round(maxSourceBytes / (1024 * 1024))} MB.`);
  }

  let bitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    throw new Error("Gambar tidak dapat dibuka. Coba file JPG, PNG, atau WebP.");
  }

  try {
    const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height));
    let width = Math.max(1, Math.round(bitmap.width * scale));
    let height = Math.max(1, Math.round(bitmap.height * scale));
    const canvas = document.createElement("canvas");
    const context = canvas.getContext("2d", { alpha: true });
    if (!context) throw new Error("Browser tidak mendukung kompresi gambar.");

    for (let resizeAttempt = 0; resizeAttempt < 7; resizeAttempt += 1) {
      canvas.width = width;
      canvas.height = height;
      context.clearRect(0, 0, width, height);
      context.drawImage(bitmap, 0, 0, width, height);

      for (let quality = 0.9; quality >= 0.62; quality -= 0.07) {
        const blob = await toWebpBlob(canvas, quality);
        if (blob.size <= maxOutputBytes) {
          const baseName = file.name.replace(/\.[^.]+$/, "") || "image";
          return new File([blob], `${baseName}.webp`, {
            type: "image/webp",
            lastModified: Date.now(),
          });
        }
      }

      width = Math.max(1, Math.round(width * 0.82));
      height = Math.max(1, Math.round(height * 0.82));
    }
  } finally {
    bitmap.close?.();
  }

  throw new Error("Gambar tetap lebih dari 1 MB setelah dikompres. Pilih gambar lain yang lebih kecil.");
}

export const IMAGE_UPLOAD_LIMITS = Object.freeze({
  sourceBytes: MAX_SOURCE_BYTES,
  outputBytes: MAX_OUTPUT_BYTES,
  maxDimension: 1800,
  acceptedTypes: Object.freeze([...ACCEPTED_IMAGE_TYPES]),
});
