FROM node:18-alpine AS base

# Instale dependências somente quando necessário
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Instale dependências com base no gerenciador de pacotes preferido
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Reconstrua o código-fonte somente quando necessário
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js coleta dados de telemetria completamente anônimos sobre o uso geral.
# Saiba mais aqui: https://nextjs.org/telemetry
# Remova o comentário da linha a seguir caso queira desabilitar a telemetria durante a construção.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build

# Se estiver usando npm, comente acima e use abaixo
#EXECUTAR npm executar compilação

# Imagem de produção, copie todos os arquivos e execute em seguida
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
# Remova o comentário da linha a seguir caso queira desabilitar a telemetria durante o tempo de execução.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Defina a permissão correta para o cache de pré-renderização
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Aproveite automaticamente os rastreamentos de saída para reduzir o tamanho da imagem
# https://nextjs.org/docs/advanced-features/output-file-tracing

# COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
# COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
# configura o nome do host como localhost
ENV HOSTNAME "*"

# server.js é criado pela próxima compilação a partir da saída independente
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD ["node", "server.js"]