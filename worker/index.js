// Password gate for the private preview. Fails closed: without PREVIEW_PASSWORD
// nobody gets in, unless PUBLIC is set to "true" when Vasiliki approves launch.
export default {
  async fetch(request, env) {
    if (env.PUBLIC !== 'true') {
      const header = request.headers.get('Authorization') || '';
      let password = '';
      if (header.startsWith('Basic ')) {
        try {
          const decoded = new TextDecoder().decode(Uint8Array.from(atob(header.slice(6)), c => c.charCodeAt(0)));
          password = decoded.slice(decoded.indexOf(':') + 1);
        } catch {}
      }
      if (!env.PREVIEW_PASSWORD || password !== env.PREVIEW_PASSWORD) {
        return new Response('Ιδιωτική προεπισκόπηση more Drama. Απαιτείται κωδικός.', {
          status: 401,
          headers: {
            'WWW-Authenticate': 'Basic realm="more Drama preview", charset="UTF-8"',
            'Content-Type': 'text/plain; charset=utf-8',
            'X-Robots-Tag': 'noindex',
          },
        });
      }
    }
    return env.ASSETS.fetch(request);
  },
};
