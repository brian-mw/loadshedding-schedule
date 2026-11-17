import 'dotenv/config';
import type { IncomingMessage, ServerResponse } from 'http';
import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import locationsRoutes from './routes/locations';
import powerWindowsRoutes from './routes/powerWindows';
import programmesRoutes from './routes/programmes';
import statusReportsRoutes from './routes/statusReports';

function buildApp() {
  const app = Fastify({ logger: true });

  app.register(cors, { origin: true });

  function registerRoutes(server: FastifyInstance) {
    server.get('/health', async () => ({ ok: true }));
    server.register(locationsRoutes);
    server.register(powerWindowsRoutes);
    server.register(programmesRoutes);
    server.register(statusReportsRoutes);
  }

  app.register(registerRoutes);
  app.register(registerRoutes, { prefix: '/api' });

  return app;
}

const port = Number(process.env.PORT ?? 3000);

async function start() {
  const app = buildApp();
  await app.listen({ port, host: '0.0.0.0' });
}

// Only listen when run directly (local dev / Docker) - Vercel instead imports
// this module for its default-exported handler below.
if (require.main === module) {
  start().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

let app: ReturnType<typeof buildApp> | null = null;
let ready: PromiseLike<unknown> | null = null;

export default async function handler(req: IncomingMessage, res: ServerResponse) {
  if (!app) {
    app = buildApp();
    ready = app.ready();
  }
  await ready;
  app.server.emit('request', req, res);
}
