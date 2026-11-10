import type { FastifyInstance } from 'fastify';
import { prisma } from '../prisma';

// A report stays in effect for 2 hours before it's considered stale - long
// enough to be useful, short enough that a claim doesn't mislead for long
// after the real status has moved on.
const FRESHNESS_HOURS = 2;
const OFFICIAL_THRESHOLD = 3;

interface ReportBody {
  location?: string;
  groupCode?: string;
  deviceId?: string;
  status?: 'ON' | 'OFF';
}

interface StatusQuery {
  location?: string;
  groupCode?: string;
}

async function aggregate(location: string, groupCode: string) {
  const since = new Date(Date.now() - FRESHNESS_HOURS * 60 * 60 * 1000);
  const grouped = await prisma.statusReport.groupBy({
    by: ['status'],
    where: { location, groupCode, reportedAt: { gte: since } },
    _count: { _all: true },
  });
  if (grouped.length === 0) {
    return { status: null, reporterCount: 0, official: false };
  }
  const leading = grouped.reduce((a, b) => (b._count._all > a._count._all ? b : a));
  return {
    status: leading.status,
    reporterCount: leading._count._all,
    official: leading._count._all >= OFFICIAL_THRESHOLD,
  };
}

export default async function statusReportsRoutes(app: FastifyInstance) {
  app.post<{ Body: ReportBody }>('/status-reports', async (request, reply) => {
    const { location, groupCode, deviceId, status } = request.body ?? {};
    if (!location || !groupCode || !deviceId || (status !== 'ON' && status !== 'OFF')) {
      return reply.code(400).send({
        error: 'location, groupCode, deviceId, and status (ON|OFF) are required',
      });
    }
    await prisma.statusReport.upsert({
      where: { location_groupCode_deviceId: { location, groupCode, deviceId } },
      create: { location, groupCode, deviceId, status },
      update: { status, reportedAt: new Date() },
    });
    return reply.send(await aggregate(location, groupCode));
  });

  app.get<{ Querystring: StatusQuery }>('/status-reports', async (request, reply) => {
    const { location, groupCode } = request.query;
    if (!location || !groupCode) {
      return reply.code(400).send({ error: 'location and groupCode are required query params' });
    }
    return reply.send(await aggregate(location, groupCode));
  });
}
