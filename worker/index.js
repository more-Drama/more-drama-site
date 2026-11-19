// Password gate for the private preview. Fails closed: without PREVIEW_PASSWORD
// nobody gets in, unless PUBLIC is set to "true" when Vasiliki approves launch.
const headers = { 'Content-Type': 'text/plain; charset=utf-8', 'X-Robots-Tag': 'noindex' };

export default {
  async fetch(request, env) {
    if (env.PUBLIC !== 'true') {
      const expected = (env.PREVIEW_PASSWORD || '').trim();
      if (!expected) {
        return new Response(
          'Ο κωδικός δεν έχει ρυθμιστεί ακόμα στο site (λείπει το PREVIEW_PASSWORD από τα Variables and Secrets του Worker).',
          { status: 503, headers },
        );
      }
      const header = request.headers.get('Authorization') || '';
      let user = '';
      let password = '';
      if (header.startsWith('Basic ')) {
        try {
          const decoded = new TextDecoder().decode(Uint8Array.from(atob(header.slice(6)), c => c.charCodeAt(0)));
          const i = decoded.indexOf(':');
          user = decoded.slice(0, i).trim();
          password = decoded.slice(i + 1).trim();
        } catch {}
      }
      if (password !== expected && user !== expected) {
        return new Response('Ιδιωτική προεπισκόπηση more Drama. Λάθος κωδικός.', {
          status: 401,
          headers: { ...headers, 'WWW-Authenticate': 'Basic realm="more Drama preview", charset="UTF-8"' },
        });
      }
    }
    return env.ASSETS.fetch(request);
  },
};
