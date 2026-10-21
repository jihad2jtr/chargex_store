import type { Config, Context } from "@netlify/functions";
import serverless from "serverless-http";

if (!process.env.MONGODB_URI) {
  process.env.MONGODB_URI =
    'mongodb+srv://jihad2jus:l9GrLciVEUvvK8Fd@jihad.8dyvx.mongodb.net/jgo?retryWrites=true&w=majority&appName=jihad';
}
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = 'layan_chargex_jwt_secret_key_2026_secure';
}
if (!process.env.JWT_REFRESH_SECRET) {
  process.env.JWT_REFRESH_SECRET = 'layan_chargex_refresh_secret_key_2026_secure';
}

let serverlessHandler: any;

async function getHandler() {
  if (!serverlessHandler) {
    const main = await import("../../dist/main.js");
    const app = await main.bootstrapServer();
    serverlessHandler = serverless(app);
  }
  return serverlessHandler;
}

// Netlify Lambda v1 handler format
export const handler = async (event: any, context: any) => {
  const h = await getHandler();
  return h(event, context);
};

// Netlify v2 Web Standard Request format
export default async (req: Request, context: Context) => {
  if (typeof Request !== 'undefined' && req instanceof Request) {
    const url = new URL(req.url);
    const headers: Record<string, string> = {};
    req.headers.forEach((val, key) => {
      headers[key] = val;
    });

    let body = '';
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      try {
        body = await req.text();
      } catch (e) {}
    }

    const event = {
      rawUrl: req.url,
      path: url.pathname,
      httpMethod: req.method,
      headers,
      queryStringParameters: Object.fromEntries(url.searchParams.entries()),
      body: body || undefined,
      isBase64Encoded: false,
    };

    const h = await getHandler();
    const result = await h(event, context);

    return new Response(result.body, {
      status: result.statusCode,
      headers: result.headers as any,
    });
  }

  const h = await getHandler();
  return h(req, context);
};

export const config: Config = {
  path: "/*",
  preferStatic: true,
};
