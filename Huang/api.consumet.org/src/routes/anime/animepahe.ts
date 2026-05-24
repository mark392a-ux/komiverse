import { FastifyRequest, FastifyReply, FastifyInstance, RegisterOptions } from 'fastify';
import { ANIME } from '@consumet/extensions';

import cache from '../../utils/cache';
import { redis, REDIS_TTL } from '../../main';
import { Redis } from 'ioredis';

const routes = async (fastify: FastifyInstance, options: RegisterOptions) => {
  const animepahe = new ANIME.AnimePahe();
  const animepaheDomains = [
    'https://animepahe.org',
    'https://animepahe.com',
    'https://animepahe.pw',
    'https://animepahe.si',
  ];

  const provider = animepahe as any;
  const originalHeaders:
    | ((sessionId: string | false) => Record<string, string>)
    | null = typeof provider.Headers === 'function' ? provider.Headers.bind(provider) : null;

  const applyDomain = (domain: string): void => {
    provider.baseUrl = domain;
    if (!originalHeaders) {
      return;
    }

    const authority = new URL(domain).host;
    provider.Headers = (sessionId: string | false) => {
      const headers = originalHeaders(sessionId) ?? {};
      return {
        ...headers,
        authority,
        host: authority,
        referer: sessionId ? `${domain}/anime/${sessionId}` : `${domain}/`,
      };
    };
  };

  const shouldTryNextDomain = (err: unknown): boolean => {
    const message = String((err as { message?: unknown })?.message ?? err).toLowerCase();
    return (
      message.includes('eai_again') ||
      message.includes('enotfound') ||
      message.includes('getaddrinfo') ||
      message.includes('timeout') ||
      message.includes('etimedout') ||
      message.includes('econnrefused') ||
      message.includes('ehostunreach')
    );
  };

  const runWithDomainFallback = async <T>(task: () => Promise<T>): Promise<T> => {
    let lastError: unknown;
    for (const domain of animepaheDomains) {
      applyDomain(domain);
      try {
        return await task();
      } catch (err) {
        lastError = err;
        if (!shouldTryNextDomain(err)) {
          break;
        }
      }
    }

    if (lastError instanceof Error) {
      throw lastError;
    }
    throw new Error('AnimePahe request failed');
  };

  // Prefer current official domains first; keep .si as final fallback.
  applyDomain(animepaheDomains[0]);

  fastify.get('/', (_, rp) => {
    rp.status(200).send({
      intro: `Welcome to the animepahe provider: check out the provider's website @ ${animepahe.toString.baseUrl}`,
      routes: ['/:query', '/info/:id', '/watch/:episodeId', '/recent-episodes'],
      active_domains: animepaheDomains,
      documentation: 'https://docs.consumet.org/#tag/animepahe',
    });
  });

  fastify.get('/:query', async (request: FastifyRequest, reply: FastifyReply) => {
    const query = (request.params as { query: string }).query;

    try {
      let res = redis
        ? await cache.fetch(
            redis as Redis,
            `animepahe:search:${query}`,
            async () => await runWithDomainFallback(() => animepahe.search(query)),
            REDIS_TTL,
          )
        : await runWithDomainFallback(() => animepahe.search(query));

      reply.status(200).send(res);
    } catch (err) {
      reply.status(500).send({
        message: (err as { message?: unknown })?.message ?? 'AnimePahe search failed',
      });
    }
  });

  fastify.get(
    '/recent-episodes',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const page = (request.query as { page: number }).page;
      try {
        let res = redis
          ? await cache.fetch(
              redis as Redis,
              `animepahe:recent-episodes:${page}`,
              async () =>
                await runWithDomainFallback(() => animepahe.fetchRecentEpisodes(page)),
              REDIS_TTL,
            )
          : await runWithDomainFallback(() => animepahe.fetchRecentEpisodes(page));

        reply.status(200).send(res);
      } catch (error) {
        reply.status(500).send({
          message:
            (error as { message?: unknown })?.message ?? 'AnimePahe recent episodes failed',
        });
      }
    },
  );

  fastify.get('/info/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const id = decodeURIComponent((request.params as { id: string }).id);
    const episodePage = (request.query as { episodePage: number }).episodePage;

    try {
      let res = redis
        ? await cache.fetch(
            redis as Redis,
            `animepahe:info:${id}:${episodePage}`,
            async () =>
              await runWithDomainFallback(() => animepahe.fetchAnimeInfo(id, episodePage)),
            REDIS_TTL,
          )
        : await runWithDomainFallback(() => animepahe.fetchAnimeInfo(id, episodePage));

      reply.status(200).send(res);
    } catch (err) {
      reply.status(500).send({
        message: (err as { message?: unknown })?.message ?? 'AnimePahe info failed',
      });
    }
  });

  fastify.get('/watch', async (request: FastifyRequest, reply: FastifyReply) => {
    const episodeId = (request.query as { episodeId: string }).episodeId;

    if (typeof episodeId === 'undefined')
      return reply.status(400).send({ message: 'episodeId is required' });

    try {
      let res = redis
        ? await cache.fetch(
            redis as Redis,
            `animepahe:watch:${episodeId}`,
            async () =>
              await runWithDomainFallback(() => animepahe.fetchEpisodeSources(episodeId)),
            REDIS_TTL,
          )
        : await runWithDomainFallback(() => animepahe.fetchEpisodeSources(episodeId));

      reply.status(200).send(res);
    } catch (err) {
      console.log(err);
      reply.status(500).send({
        message: (err as { message?: unknown })?.message ?? 'AnimePahe watch failed',
      });
    }
  });
};

export default routes;
