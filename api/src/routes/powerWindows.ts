import type { FastifyInstance } from 'fastify';
import { prisma } from '../prisma';

interface Query {
  subgroup?: string;
  from?: string;
  to?: string;
}

function formatTime(d: Date): string {
  return d.toISOString().substring(11, 19);
}

export default async function powerWindowsRoutes(app: FastifyInstance) {
  app.get<{ Querystring: Query }>('/power-windows', async (request, reply) => {
    const { subgroup, from, to } = request.query;
    if (!subgroup || !from || !to) {
      return reply.code(400).send({ error: 'subgroup, from, and to are required query params' });
    }
    const rows = await prisma.powerWindow.findMany({
      where: {
        subgroup,
        date: { gte: new Date(from), lte: new Date(to) },
      },
      select: {
        date: true,
        subgroup: true,
        slotIndex: true,
        startTime: true,
        endTime: true,
        status: true,
      },
      orderBy: [{ date: 'asc' }, { slotIndex: 'asc' }],
    });
    // Prisma represents a Postgres `time` column as a JS Date anchored to the
    // 1970-01-01 epoch - format it down to a plain "HH:MM:SS" string so API
    // clients get the time-only value the field actually represents.
    return reply.send(
      rows.map((r) => ({
        ...r,
        startTime: formatTime(r.startTime),
        endTime: formatTime(r.endTime),
      })),
    );
  });
}
