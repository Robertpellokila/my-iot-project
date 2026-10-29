# Player photo person segmentation

Model: Google MediaPipe SelfieSegmenter, square 256×256, float16, version 1.
Source: https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite
SHA-256: `191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b`.

Runtime: `@mediapipe/tasks-vision` 1.1.1, Apache-2.0. Matching SIMD/no-SIMD WASM files
are bundled by Vite and loaded only when background removal is requested. The
model is served by this app; photographs are processed on the player's device.
No external photo-processing endpoint or API key is required. Segmentation is an
estimate; the UI retains the original and offers restore/retry controls.
