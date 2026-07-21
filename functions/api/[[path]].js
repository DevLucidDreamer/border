// Cloudflare Pages Function — AI 프록시.
//
// 브라우저가 API 키를 절대 보지 못하도록, 웹앱은 같은 오리진의 이 함수를
// 부르고 여기서 서버 측 시크릿으로 키를 주입해 실제 provider로 중계한다.
// (직접 호출 시의 CORS 차단·키 노출 두 문제를 한 번에 해결한다.)
//
//   /api/anthropic/v1/messages          -> https://api.anthropic.com/...  (x-api-key)
//   /api/openai/v1/audio/transcriptions -> https://api.openai.com/...      (Bearer)
//   /api/openai/v1/audio/speech
//   /api/openai/v1/images/generations
//
// Cloudflare Pages → Settings → Environment variables 에 시크릿으로 넣을 것:
//   ANTHROPIC_API_KEY, OPENAI_API_KEY

const UPSTREAM = {
  anthropic: 'https://api.anthropic.com',
  openai: 'https://api.openai.com',
};

// 이 프록시로 호출을 허용하는 경로만 통과시킨다(공개 오픈프록시 오남용 축소).
// ponytail: 경로 화이트리스트만 검사 — 완전한 남용 방지(인증/레이트리밋)는
// Cloudflare Access·Rate Limiting으로 별도 설정. 여기선 데모 수준으로 둔다.
const ALLOWED = new Set([
  'anthropic/v1/messages',
  'openai/v1/audio/transcriptions',
  'openai/v1/audio/speech',
  'openai/v1/images/generations',
]);

export async function onRequest(context) {
  const { request, env, params } = context;
  const parts = params.path || []; // 예: ['anthropic','v1','messages']
  const provider = parts[0];
  const base = UPSTREAM[provider];
  const routeKey = parts.join('/');

  if (!base || !ALLOWED.has(routeKey)) {
    return new Response('Not found', { status: 404 });
  }

  const url = new URL(request.url);
  const target = `${base}/${parts.slice(1).join('/')}${url.search}`;

  // 클라이언트 헤더를 복사하되 host를 지우고 서버 키를 주입한다.
  // content-type(멀티파트 boundary 포함)은 그대로 보존해야 STT가 동작한다.
  const headers = new Headers(request.headers);
  headers.delete('host');
  if (provider === 'anthropic') {
    if (!env.ANTHROPIC_API_KEY) {
      return new Response('ANTHROPIC_API_KEY not set on Cloudflare', { status: 500 });
    }
    headers.set('x-api-key', env.ANTHROPIC_API_KEY);
    if (!headers.has('anthropic-version')) {
      headers.set('anthropic-version', '2023-06-01');
    }
  } else {
    if (!env.OPENAI_API_KEY) {
      return new Response('OPENAI_API_KEY not set on Cloudflare', { status: 500 });
    }
    headers.set('Authorization', `Bearer ${env.OPENAI_API_KEY}`);
  }

  const method = request.method;
  const init = {
    method,
    headers,
    body: method === 'GET' || method === 'HEAD' ? undefined : request.body,
  };
  if (init.body) init.duplex = 'half'; // 스트리밍 본문(멀티파트) 전송에 필요

  const upstream = await fetch(target, init);

  // 응답을 그대로 흘려보낸다. resp.body는 이미 디코딩된 스트림이므로
  // content-encoding/length 헤더는 제거해야 브라우저가 중복 해제하지 않는다.
  const respHeaders = new Headers(upstream.headers);
  respHeaders.delete('content-encoding');
  respHeaders.delete('content-length');
  return new Response(upstream.body, {
    status: upstream.status,
    headers: respHeaders,
  });
}
