import type { FastifyInstance } from 'fastify';
import { prisma } from '../prisma';

export default async function programmesRoutes(app: FastifyInstance) {
  app.get('/programmes/latest', async (_request, reply) => {
    const row = await prisma.programme.findFirst({
      select: {
        weekLabel: true,
        title: true,
        issueDate: true,
        weekStart: true,
        weekEnd: true,
      },
      orderBy: { weekStart: 'desc' },
    });
    if (!row) {
      return reply.code(404).send({ error: 'no programmes loaded yet' });
    }
    return reply.send(row);
  });
}
