// Create/update the liveSessions of one week from a local CSV (see events/events.example.csv).
// Dry-run by default; --apply writes. Never deletes.
// Usage (from functions/):
//   gcloud auth application-default login
//   npm run events:create -- --week 2026-12-07            # dry-run
//   npm run events:create -- --week 2026-12-07 --apply    # write
// Options: --file events/events.csv   (default)   --week any date in the week (default: next week)
// Against the emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-proplay npm run events:create -- ...
import {readFileSync} from 'node:fs';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {
  parseCsv, parseRows, weekMonday, occurrence, buildLiveDoc, buildTemplateDoc,
  diffFields, liveId, templateId, todayLima, addDays,
} from '../src/recurringEvents';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const apply = process.argv.includes('--apply');
  const file = arg('file') ?? 'events/events.csv';
  const weekArg = arg('week');
  const monday = weekArg
    ? weekMonday(weekArg)
    : weekMonday(addDays(todayLima(), 7));

  const {rows, errors} = parseRows(parseCsv(readFileSync(file, 'utf8')));
  if (errors.length) {
    console.error(errors.join('\n'));
    process.exit(1);
  }

  const projectId = process.env.GCLOUD_PROJECT ?? 'proplay-eac23';
  initializeApp({projectId});
  const db = getFirestore();
  console.log(`${apply ? 'APPLY' : 'DRY-RUN'} project=${projectId} week=${monday} rows=${rows.length}`);

  const groups = new Map<string, boolean>();
  const counts = {CREATE: 0, UPDATE: 0, UNCHANGED: 0, WARN: 0, MISSING_GROUP: 0};

  for (const row of rows) {
    if (!groups.has(row.groupId)) groups.set(row.groupId, (await db.doc(`groups/${row.groupId}`).get()).exists);
    if (!groups.get(row.groupId)) {
      console.log(`SKIP   ${row.key}  group ${row.groupId} not found`);
      counts.MISSING_GROUP++;
      continue;
    }
    const {date, start, end} = occurrence(row, monday);
    const id = liveId(row, date);
    const liveRef = db.doc(`liveSessions/${id}`);
    const tplRef = db.doc(`sessionTemplates/${templateId(row)}`);
    const desired = buildLiveDoc(row, start, end);
    const template = buildTemplateDoc(row, start, end);

    // Read, diff and write in one transaction so a concurrent join cannot slip past the guards.
    const decide = (data: Record<string, any> | undefined) => {
      if (!data) return {action: 'CREATE' as const, update: {}, warnings: [] as string[]};
      const {update, warnings} = diffFields(data, desired);
      return {action: Object.keys(update).length ? 'UPDATE' as const : 'UNCHANGED' as const, update, warnings};
    };
    const out = apply
      ? await db.runTransaction(async (t) => {
        const r = decide((await t.get(liveRef)).data());
        if (r.action === 'CREATE') t.set(liveRef, desired);
        else if (r.action === 'UPDATE') t.update(liveRef, r.update);
        t.set(tplRef, template, {merge: true}); // latest rule for the series
        return r;
      })
      : decide((await liveRef.get()).data());

    for (const w of out.warnings) {
      console.log(`WARN   ${id}  ${w}`);
      counts.WARN++;
    }
    const detail = out.action === 'CREATE' ? `  ${row.title} ${row.start}`
      : out.action === 'UPDATE' ? `  (${Object.keys(out.update).join(', ')})` : '';
    console.log(`${out.action.padEnd(6)} ${id}${detail}`);
    counts[out.action]++;
  }
  console.log(JSON.stringify(counts), apply ? 'written' : 'nothing written (dry-run; add --apply)');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
