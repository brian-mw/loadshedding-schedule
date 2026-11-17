import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import locationsRoutes from './routes/locations';
import powerWindowsRoutes from './routes/powerWindows';
import programmesRoutes from './routes/programmes';
import statusReportsRoutes from './routes/statusReports';

export function buildApp() {
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
