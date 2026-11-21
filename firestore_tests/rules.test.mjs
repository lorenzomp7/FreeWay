import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { doc, setDoc, collection, getDocs, updateDoc, deleteDoc, serverTimestamp, Timestamp, arrayUnion, arrayRemove, writeBatch } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-freeway',
  firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8089 },
});
const ctx = (uid, provider) => env.authenticatedContext(uid, { firebase: { sign_in_provider: provider } }).firestore();
const alice = ctx('alice', 'password');
const guest = ctx('guest1', 'anonymous');
const guest2 = ctx('guest2', 'anonymous');
const anon = env.unauthenticatedContext().firestore();
const report = (uid, extra = {}) => ({ lat: 45.54, lng: 10.22, type: 'Gradino', category: 'Dislivello e pavimentazione', timestamp: serverTimestamp(), userId: uid, ...extra });
let ok = 0, fail = 0;
async function check(name, p) { try { await p; ok++; console.log('PASS', name); } catch (e) { fail++; console.log('FAIL', name, e.message); } }

// Come l'app: segnalazione + limiti nella stessa scrittura.
const add = (db, uid, id, data) => { const b = writeBatch(db); b.set(doc(db, 'segnalazioni/' + id), data ?? report(uid)); b.set(doc(db, 'limiti/' + uid), { lastReportAt: serverTimestamp() }, { merge: true }); return b.commit(); };
const remove = (db, uid, id) => { const b = writeBatch(db); b.delete(doc(db, 'segnalazioni/' + id)); b.set(doc(db, 'limiti/' + uid), { lastRemovalAt: serverTimestamp() }, { merge: true }); return b.commit(); };
// Sposta indietro nel tempo i limiti di un utente.
const age = (uid, field, seconds) => env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'limiti/' + uid), { [field]: Timestamp.fromMillis(Date.now() - seconds * 1000) }, { merge: true }));
const seed = (id, data) => env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'segnalazioni/' + id), data));

// --- creazione e limite di frequenza ---
await check('utente crea segnalazione', assertSucceeds(add(alice, 'alice', 'a1')));
await check('seconda segnalazione subito dopo rifiutata', assertFails(add(alice, 'alice', 'a2')));
await age('alice', 'lastReportAt', 20);
await check('dopo 20 s ancora rifiutata', assertFails(add(alice, 'alice', 'a2')));
await age('alice', 'lastReportAt', 31);
await check('dopo 31 s accettata', assertSucceeds(add(alice, 'alice', 'a2')));
await check('segnalazione senza aggiornare i limiti rifiutata', (async () => { await age('alice', 'lastReportAt', 60); await assertFails(setDoc(doc(alice, 'segnalazioni/a3'), report('alice'))); })());
await check('limiti con ora del client rifiutati', assertFails(setDoc(doc(guest, 'limiti/guest1'), { lastReportAt: Timestamp.fromMillis(0) })));
await check('limiti di un altro utente rifiutati', assertFails(setDoc(doc(guest, 'limiti/alice'), { lastReportAt: serverTimestamp() }, { merge: true })));
await check('campo estraneo nei limiti rifiutato', assertFails(setDoc(doc(guest, 'limiti/guest1'), { lastReportAt: serverTimestamp(), extra: 1 })));
await check('ospite crea segnalazione', assertSucceeds(add(guest, 'guest1', 'g1')));
await check('non autenticato non legge', assertFails(getDocs(collection(anon, 'segnalazioni'))));
await check('ospite legge', assertSucceeds(getDocs(collection(guest, 'segnalazioni'))));
await check('non autenticato non crea', assertFails(add(anon, 'x', 'n1')));

// --- validazione dei campi (limiti invecchiati prima di ogni prova) ---
const bad = async (name, data) => { await age('alice', 'lastReportAt', 60); await check(name, assertFails(add(alice, 'alice', 'bad', data))); };
await bad('userId altrui rifiutato', report('bob'));
await bad('timestamp client rifiutato', report('alice', { timestamp: Timestamp.fromDate(new Date(2020, 0, 1)) }));
await bad('campo extra rifiutato', report('alice', { extra: 1 }));
await bad('lat fuori range rifiutata', report('alice', { lat: 120 }));
await bad('tipo vuoto rifiutato', report('alice', { type: '' }));
await bad('categoria sconosciuta rifiutata', report('alice', { category: 'Inventata' }));
await check('modifica del tipo rifiutata', assertFails(updateDoc(doc(alice, 'segnalazioni/a1'), { type: 'Altro' })));

// --- conferme ---
const confirm = (db, uid, id = 'a1') => updateDoc(doc(db, 'segnalazioni/' + id), { confirmedBy: arrayUnion(uid), lastConfirmedAt: serverTimestamp() });
await check('ospite conferma ostacolo altrui', assertSucceeds(confirm(guest, 'guest1')));
await check('seconda conferma dello stesso utente rifiutata', assertFails(confirm(guest, 'guest1')));
await check('autrice non può confermare', assertFails(confirm(alice, 'alice')));
await check('conferma a nome di altri rifiutata', assertFails(confirm(ctx('dan', 'password'), 'eve')));

// --- voti "non c'è più" ---
const notThere = (db, uid, id = 'a1') => updateDoc(doc(db, 'segnalazioni/' + id), { notThereBy: arrayUnion(uid), lastNotThereAt: serverTimestamp() });
await check('ospite vota che non c\'è più', assertSucceeds(notThere(guest2, 'guest2')));
await check('secondo voto dello stesso utente rifiutato', assertFails(notThere(guest2, 'guest2')));
await check('autrice non può votare la propria', assertFails(notThere(alice, 'alice')));
await check('voto a nome di altri rifiutato', assertFails(notThere(ctx('dan', 'password'), 'eve')));
await check('voto con ora del client rifiutato', assertFails(updateDoc(doc(guest, 'segnalazioni/a1'), { notThereBy: arrayUnion('guest1'), lastNotThereAt: Timestamp.fromMillis(0) })));
await check('voto insieme ad altre modifiche rifiutato', assertFails(updateDoc(doc(guest, 'segnalazioni/a1'), { notThereBy: arrayUnion('guest1'), lastNotThereAt: serverTimestamp(), type: 'Altro' })));
await check('non autenticato non vota', assertFails(notThere(anon, 'x')));

// --- rimozione e limite di frequenza ---
await check('ospite non cancella altrui', assertFails(remove(guest2, 'guest2', 'a1')));
await check('ospite cancella la propria', assertSucceeds(remove(guest, 'guest1', 'g1')));
await check('cancellazione senza aggiornare i limiti rifiutata', (async () => { await seed('s1', { lat: 1, lng: 1, type: 'x', timestamp: Timestamp.now(), userId: 'z' }); const b = writeBatch(alice); b.delete(doc(alice, 'segnalazioni/s1')); await assertFails(b.commit()); })());
await check('utente cancella altrui', assertSucceeds(remove(alice, 'alice', 's1')));
await check('seconda rimozione subito dopo rifiutata', (async () => { await seed('s2', { lat: 1, lng: 1, type: 'x', timestamp: Timestamp.now(), userId: 'z' }); await assertFails(remove(alice, 'alice', 's2')); })());
await age('alice', 'lastRemovalAt', 11);
await check('rimozione dopo 11 s accettata', assertSucceeds(remove(alice, 'alice', 's2')));
await check('rimozione non cambia il limite delle segnalazioni', (async () => { await age('alice', 'lastReportAt', 60); await assertSucceeds(add(alice, 'alice', 'a9')); })());

// --- foto ---
const photo = (uid, extra = {}) => ({ data: '/9j/4AAQSkZJRg==', userId: uid, timestamp: serverTimestamp(), ...extra });
const addWithPhoto = (db, uid, id, { reportData, photoData, withPhoto = true } = {}) => {
  const b = writeBatch(db);
  b.set(doc(db, 'segnalazioni/' + id), reportData ?? report(uid, { hasPhoto: true }));
  if (withPhoto) b.set(doc(db, 'foto/' + id), photoData ?? photo(uid));
  b.set(doc(db, 'limiti/' + uid), { lastReportAt: serverTimestamp() }, { merge: true });
  return b.commit();
};
const fresh = () => age('alice', 'lastReportAt', 60);
await fresh();
await check('segnalazione con foto accettata', assertSucceeds(addWithPhoto(alice, 'alice', 'p1')));
await check('ospite legge la foto', assertSucceeds(getDocs(collection(guest, 'foto'))));
await check('non autenticato non legge le foto', assertFails(getDocs(collection(anon, 'foto'))));
await fresh();
await check('hasPhoto senza foto rifiutato', assertFails(addWithPhoto(alice, 'alice', 'p2', { withPhoto: false })));
await fresh();
await check('foto senza hasPhoto rifiutata', assertFails(addWithPhoto(alice, 'alice', 'p3', { reportData: report('alice') })));
await fresh();
await check('foto a nome di altri rifiutata', assertFails(addWithPhoto(alice, 'alice', 'p4', { photoData: photo('bob') })));
await fresh();
await check('foto troppo grande rifiutata', assertFails(addWithPhoto(alice, 'alice', 'p5', { photoData: photo('alice', { data: 'a'.repeat(700001) }) })));
await fresh();
await check('foto con campo extra rifiutata', assertFails(addWithPhoto(alice, 'alice', 'p6', { photoData: photo('alice', { extra: 1 }) })));
await check('foto aggiunta a segnalazione esistente rifiutata', assertFails(setDoc(doc(alice, 'foto/a9'), photo('alice'))));
await check('foto sovrascritta rifiutata', assertFails(setDoc(doc(guest, 'foto/p1'), photo('guest1'))));
await check('foto cancellata da sola rifiutata', assertFails(writeBatch(alice).delete(doc(alice, 'foto/p1')).commit()));
await age('alice', 'lastRemovalAt', 11);
await check('foto cancellata con la segnalazione', assertSucceeds((() => { const b = writeBatch(alice); b.delete(doc(alice, 'segnalazioni/p1')); b.delete(doc(alice, 'foto/p1')); b.set(doc(alice, 'limiti/alice'), { lastRemovalAt: serverTimestamp() }, { merge: true }); return b.commit(); })()));

// --- eliminazione dei propri dati (art. 17 GDPR) ---
await seed('e1', { lat: 1, lng: 1, type: 'x', timestamp: Timestamp.now(), userId: 'erin', confirmedBy: ['frank', 'erin2'], notThereBy: ['frank'] });
await seed('e2', { lat: 1, lng: 1, type: 'x', timestamp: Timestamp.now(), userId: 'frank' });
await seed('e3', { lat: 1, lng: 1, type: 'x', timestamp: Timestamp.now(), userId: 'frank' });
const frank = ctx('frank', 'anonymous');
await check('ospite cancella le proprie senza attendere', (async () => { await assertSucceeds(deleteDoc(doc(frank, 'segnalazioni/e2'))); await assertSucceeds(deleteDoc(doc(frank, 'segnalazioni/e3'))); })());
await check('ritiro della propria conferma', assertSucceeds(updateDoc(doc(frank, 'segnalazioni/e1'), { confirmedBy: arrayRemove('frank') })));
await check('ritiro del proprio voto', assertSucceeds(updateDoc(doc(frank, 'segnalazioni/e1'), { notThereBy: arrayRemove('frank') })));
await check('ritiro della conferma di un altro rifiutato', assertFails(updateDoc(doc(frank, 'segnalazioni/e1'), { confirmedBy: arrayRemove('erin2') })));
await check('ritiro insieme ad altre modifiche rifiutato', (async () => { await seed('e4', { lat: 1, lng: 1, type: 'x', timestamp: Timestamp.now(), userId: 'erin', confirmedBy: ['frank'] }); await assertFails(updateDoc(doc(frank, 'segnalazioni/e4'), { confirmedBy: arrayRemove('frank'), type: 'Altro' })); })());
await check('ospite non cancella altrui nemmeno così', assertFails(deleteDoc(doc(frank, 'segnalazioni/e1'))));
await check('limiti cancellati subito dopo una segnalazione rifiutati', (async () => { await add(alice, 'alice', 'e5').catch(() => {}); await age('alice', 'lastRemovalAt', 60); await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'limiti/alice'), { lastReportAt: Timestamp.now() }, { merge: true })); await assertFails(deleteDoc(doc(alice, 'limiti/alice'))); })());
await check('limiti cancellati dopo i tempi minimi', (async () => { await age('alice', 'lastReportAt', 31); await age('alice', 'lastRemovalAt', 11); await assertSucceeds(deleteDoc(doc(alice, 'limiti/alice'))); })());
await check('limiti di un altro utente non cancellabili', (async () => { await age('guest1', 'lastReportAt', 60); await age('guest1', 'lastRemovalAt', 60); await assertFails(deleteDoc(doc(alice, 'limiti/guest1'))); })());

await check('altre collezioni chiuse', assertFails(setDoc(doc(alice, 'utenti/alice'), { a: 1 })));
await env.cleanup();
console.log(`\n${ok} passati, ${fail} falliti`);
process.exit(fail ? 1 : 0);
