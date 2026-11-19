import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const image = z.object({
  src: z.string().startsWith('/media/'),
  alt: z.string(),
  width: z.number().positive(),
  height: z.number().positive(),
  caption: z.string(),
  text: z.string().optional(),
});
const stories = defineCollection({
  loader: glob({ pattern: '*.json', base: './src/content/stories', generateId: ({ entry }) => entry.replace(/\.json$/, '') }),
  schema: z.object({
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    status: z.enum(['draft', 'published']),
    category: z.literal('people'),
    title: z.string().min(1),
    intro: z.string().min(1),
    cardIntro: z.string().min(1),
    signature: z.string(),
    author: z.string(),
    displayDate: z.string(),
    cover: image,
    blocks: z.array(z.object({
      layout: z.enum(['opening', 'contactSheet', 'closing']),
      items: z.array(z.discriminatedUnion('type', [
        z.object({ type: z.literal('image'), image }),
        z.object({ type: z.enum(['heading', 'paragraph', 'quote']), text: z.string() }),
      ])),
    })),
    seo: z.object({ title: z.string(), description: z.string(), keyword: z.string() }),
    disclaimer: z.string(),
  }),
});
export const collections = { stories };
