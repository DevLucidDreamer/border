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

  // 최소 헤더만 새로 구성한다. 브라우저 헤더(content-length, accept-encoding,
  // cf-*, origin 등)를 통째로 복사하면 업스트림/스트리밍 충돌로 502가 난다.
  // content-type만 보존(멀티파트 boundary 포함해야 STT가 동작)하고 키를 주입한다.
  const headers = new Headers();
  const contentType = request.headers.get('content-type');
  if (contentType) headers.set('content-type', contentType);

  if (provider === 'anthropic') {
    if (!env.ANTHROPIC_API_KEY) {
      return new Response('ANTHROPIC_API_KEY not set on Cloudflare', { status: 500 });
    }
    headers.set('x-api-key', env.ANTHROPIC_API_KEY);
    headers.set(
      'anthropic-version',
      request.headers.get('anthropic-version') || '2023-06-01',
    );
  } else {
    if (!env.OPENAI_API_KEY) {
      return new Response('OPENAI_API_KEY not set on Cloudflare', { status: 500 });
    }
    headers.set('Authorization', `Bearer ${env.OPENAI_API_KEY}`);
  }

  const method = request.method;
  // 본문을 스트리밍(duplex) 대신 통째로 읽어 넘긴다 — Pages Functions에서
  // 스트리밍 본문이 자주 502를 유발한다. 데모 크기(텍스트·오디오·PDF)라 무리 없음.
  let body;
  if (method !== 'GET' && method !== 'HEAD') {
    body = await request.arrayBuffer();
  }

  let upstream;
  try {
    upstream = await fetch(target, { method, headers, body });
  } catch (e) {
    // 업스트림 연결 실패 시 CF의 불투명한 502 대신 원인을 돌려준다.
    return new Response(`Proxy upstream fetch failed: ${e}`, { status: 502 });
  }

  // 응답 본문을 읽어 그대로 돌려준다. content-encoding/length는 이미 디코딩된
  // 본문과 충돌하므로 제거한다.
  const respBody = await upstream.arrayBuffer();
  const respHeaders = new Headers();
  const respCt = upstream.headers.get('content-type');
  if (respCt) respHeaders.set('content-type', respCt);
  return new Response(respBody, { status: upstream.status, headers: respHeaders });
}
