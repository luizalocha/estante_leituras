// Testes das regras do Firestore: operações PERMITIDAS e NEGADAS.
// Executar de dentro desta pasta:  npm install  e depois  npm run test:emulador
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const UID_A = 'usuario-A';
const UID_B = 'usuario-B';
const LIVRO_A = 'livro-da-A';

let env;

const livroValido = (ownerId) => ({
  ownerId,
  title: 'Dom Casmurro',
  author: 'Machado de Assis',
  year: 1899,
  coverUrl: null,
  workKey: '/works/OL1W',
  status: 'quero_ler',
  rating: 0,
  notes: '',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-estante',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Documento da usuária A criado sem passar pelas regras (preparação).
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'books', LIVRO_A), {
      ...livroValido(UID_A),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
});

const dbDe = (uid) => env.authenticatedContext(uid).firestore();

describe('PERMITIDO', () => {
  test('A cria um livro com o próprio UID', async () => {
    await assertSucceeds(setDoc(doc(dbDe(UID_A), 'books', 'novo'), livroValido(UID_A)));
  });

  test('A lê o próprio livro', async () => {
    await assertSucceeds(getDoc(doc(dbDe(UID_A), 'books', LIVRO_A)));
  });

  test('A lista os próprios livros filtrando por ownerId', async () => {
    const q = query(collection(dbDe(UID_A), 'books'), where('ownerId', '==', UID_A));
    await assertSucceeds(getDocs(q));
  });

  test('A atualiza status e nota do próprio livro', async () => {
    await assertSucceeds(
      updateDoc(doc(dbDe(UID_A), 'books', LIVRO_A), {
        status: 'lido',
        rating: 5,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('A remove o próprio livro', async () => {
    await assertSucceeds(deleteDoc(doc(dbDe(UID_A), 'books', LIVRO_A)));
  });
});

describe('NEGADO', () => {
  test('B não lê o livro de A', async () => {
    await assertFails(getDoc(doc(dbDe(UID_B), 'books', LIVRO_A)));
  });

  test('B não lista os livros de A', async () => {
    const q = query(collection(dbDe(UID_B), 'books'), where('ownerId', '==', UID_A));
    await assertFails(getDocs(q));
  });

  test('consulta sem filtro por ownerId é recusada', async () => {
    await assertFails(getDocs(collection(dbDe(UID_A), 'books')));
  });

  test('B não altera o livro de A', async () => {
    await assertFails(
      updateDoc(doc(dbDe(UID_B), 'books', LIVRO_A), {
        rating: 1,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('B não remove o livro de A', async () => {
    await assertFails(deleteDoc(doc(dbDe(UID_B), 'books', LIVRO_A)));
  });

  test('B não cria livro em nome de A', async () => {
    await assertFails(setDoc(doc(dbDe(UID_B), 'books', 'falso'), livroValido(UID_A)));
  });

  test('A não troca o dono do próprio livro', async () => {
    await assertFails(
      updateDoc(doc(dbDe(UID_A), 'books', LIVRO_A), {
        ownerId: UID_B,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('nota fora de 0..5 é recusada', async () => {
    await assertFails(
      updateDoc(doc(dbDe(UID_A), 'books', LIVRO_A), {
        rating: 9,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('visitante sem login não lê nada', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'books', LIVRO_A)));
  });
});
