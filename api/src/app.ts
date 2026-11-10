import Fastify from 'fastify';
import cors from '@fastify/cors';
import locationsRoutes from './routes/locations';
import powerWindowsRoutes from './routes/powerWindows';
import programmesRoutes from './routes/programmes';
import statusReportsRoutes from './routes/statusReports';

export function buildApp() {
  const app = Fastify({ logger: true });

  app.register(cors, { origin: true });

  app.get('/health', async () => ({ ok: true }));

  app.register(locationsRoutes);
  app.register(powerWindowsRoutes);
  app.register(programmesRoutes);
  app.register(statusReportsRoutes);

  return app;
}
