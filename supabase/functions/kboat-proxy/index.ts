import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/// KBOAT(www.kboat.or.kr) 는 CORS 응답 헤더를 제공하지 않고 preflight(OPTIONS) 에
/// 400 을 반환하므로 브라우저에서 직접 호출할 수 없다. Flutter 웹 빌드가 당일
/// 경주결과·최종배당·확정출주표를 읽을 수 있도록 동일 요청을 중계한다.
///
/// 중계 대상 호스트를 KBOAT 한 곳으로 고정해 임의 주소로의 SSRF 를 차단한다.
/// 호출자 인증은 `verify_jwt = true` 로 배포해 Supabase 게이트웨이에 위임한다.
/// (브라우저 preflight 는 게이트웨이가 JWT 검증에서 제외하므로 아래에서 직접 처리한다.)

const ALLOWED_HOST = "www.kboat.or.kr";
const PROXY_SEGMENT = "/kboat-proxy";
const UPSTREAM_TIMEOUT_MS = 15_000;
const MAX_RESPONSE_BYTES = 8 * 1024 * 1024;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, accept, x-requested-with, x-client-info",
  "Access-Control-Max-Age": "86400",
};

/// 업스트림으로 그대로 넘겨야 하는 헤더. multipart 요청의 boundary 가 담긴
/// content-type 이 유실되면 KBOAT 가 폼 값을 파싱하지 못한다.
const FORWARDED_REQUEST_HEADERS = [
  "accept",
  "accept-language",
  "content-type",
  "x-requested-with",
];

const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

/// `/kboat-proxy/main/race/result` → `/main/race/result`
function extractTargetPath(pathname: string): string | null {
  const marker = pathname.indexOf(PROXY_SEGMENT);
  if (marker < 0) return null;

  const path = pathname.slice(marker + PROXY_SEGMENT.length);
  if (!path.startsWith("/") || path.startsWith("//")) return null;
  if (path.includes("..")) return null;
  return path;
}

function buildUpstreamRequestHeaders(req: Request): Headers {
  const headers = new Headers();
  for (const name of FORWARDED_REQUEST_HEADERS) {
    const value = req.headers.get(name);
    if (value) headers.set(name, value);
  }
  headers.set("User-Agent", BROWSER_USER_AGENT);
  headers.set("Referer", `https://${ALLOWED_HOST}/`);
  headers.set("Origin", `https://${ALLOWED_HOST}`);
  return headers;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "GET" && req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed", method: req.method });
  }

  const incoming = new URL(req.url);
  const targetPath = extractTargetPath(incoming.pathname);
  if (targetPath === null) {
    return jsonResponse(400, {
      error: "invalid_target_path",
      hint: `${PROXY_SEGMENT}/<kboat path> 형식으로 호출하세요.`,
    });
  }

  let upstreamUrl: URL;
  try {
    upstreamUrl = new URL(`https://${ALLOWED_HOST}${targetPath}${incoming.search}`);
  } catch {
    return jsonResponse(400, { error: "invalid_target_url" });
  }
  if (upstreamUrl.host !== ALLOWED_HOST || upstreamUrl.protocol !== "https:") {
    return jsonResponse(400, { error: "host_not_allowed", host: upstreamUrl.host });
  }

  try {
    const upstreamResponse = await fetch(upstreamUrl, {
      method: req.method,
      headers: buildUpstreamRequestHeaders(req),
      body: req.method === "POST" ? await req.arrayBuffer() : undefined,
      redirect: "follow",
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });

    const payload = await upstreamResponse.arrayBuffer();
    if (payload.byteLength > MAX_RESPONSE_BYTES) {
      return jsonResponse(502, {
        error: "upstream_response_too_large",
        bytes: payload.byteLength,
      });
    }

    const headers = new Headers(CORS_HEADERS);
    headers.set(
      "Content-Type",
      upstreamResponse.headers.get("content-type") ?? "application/octet-stream",
    );
    headers.set("Cache-Control", "no-store");

    return new Response(payload, { status: upstreamResponse.status, headers });
  } catch (error) {
    const isTimeout = error instanceof DOMException && error.name === "TimeoutError";
    return jsonResponse(isTimeout ? 504 : 502, {
      error: isTimeout ? "upstream_timeout" : "upstream_fetch_failed",
      message: error instanceof Error ? error.message : String(error),
    });
  }
});
