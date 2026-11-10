FROM node:22-slim AS builder
WORKDIR /app
# placeholder so `prisma generate` can load prisma.config.ts; real value comes from compose at runtime
ENV DATABASE_URL="postgresql://user:password@localhost:5432/db"
COPY package.json package-lock.json* ./
COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npm install
COPY . .
RUN npm run build

FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV DATABASE_URL="postgresql://user:password@localhost:5432/db"
COPY package.json package-lock.json* ./
COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npm install --omit=dev && npx prisma generate
COPY --from=builder /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/src/server.js"]
