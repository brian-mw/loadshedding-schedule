import type { FastifyInstance } from 'fastify';
import { prisma } from '../prisma';

export default async function locationsRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { q?: string } }>('/locations/search', async (request, reply) => {
    const q = (request.query.q ?? '').trim();
    if (q.length < 2) {
      return reply.send([]);
    }
    const rows = await prisma.location.findMany({
      where: {
        OR: [
          { location: { contains: q, mode: 'insensitive' } },
          { affectedAreas: { contains: q, mode: 'insensitive' } },
        ],
      },
      select: { groupCode: true, region: true, location: true, affectedAreas: true },
      orderBy: { location: 'asc' },
      take: 20,
    });
    return reply.send(rows);
  });
}
