export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith("/api/")) {
      const key = env.SECRET_KEY_NAME; // secret bisa diakses di sini
      return new Response("ok");
    }
    return env.ASSETS.fetch(request);
  }
};