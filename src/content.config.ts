import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const image = z.object({
  src: z.string().startsWith('/media/'),
  alt: z.string(),
  width: z.number().positive(),
  height: z.number().positive(),
  caption: z.string(),
  text: z.string().optional(),
  focus: z.string().optional(),
  // true = η φωτογραφία δεν υπάρχει ακόμα· το src είναι το προγραμματισμένο SEO όνομα αρχείου.
  placeholder: z.boolean().optional(),
});
const stories = defineCollection({
  loader: glob({ pattern: '*.json', base: './src/content/stories', generateId: ({ entry }) => entry.replace(/\.json$/, '') }),
  schema: z.object({
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    status: z.enum(['draft', 'published']),
    category: z.enum(['people', 'culture']),
    kicker: z.string().optional(),
    order: z.number().optional(),
    // true = το άρθρο ζει στη ρίζα (/<slug>/) αντί για /culture/<slug>/.
    rootUrl: z.boolean().optional(),
    credit: z.string().optional(),
    title: z.string().min(1),
    intro: z.string().min(1),
    cardIntro: z.string().min(1),
    signature: z.string(),
    author: z.string(),
    displayDate: z.string(),
    cover: image,
    blocks: z.array(z.object({
      layout: z.enum(['opening', 'contactSheet', 'closing', 'recipe']),
      items: z.array(z.discriminatedUnion('type', [
        z.object({ type: z.literal('image'), image }),
        z.object({ type: z.enum(['heading', 'paragraph', 'quote']), text: z.string() }),
        z.object({ type: z.literal('list'), ordered: z.boolean().default(false), items: z.array(z.string()).min(1) }),
        z.object({ type: z.literal('link'), text: z.string(), href: z.string() }),
        z.object({ type: z.literal('recipe'), title: z.string(), ingredients: z.array(z.string()).min(1), steps: z.array(z.string()).min(1) }),
      ])),
    })),
    seo: z.object({ title: z.string(), description: z.string(), keyword: z.string() }),
    disclaimer: z.string(),
  }),
});
export const collections = { stories };
