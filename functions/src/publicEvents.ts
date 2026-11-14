import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {getFirestore} from 'firebase-admin/firestore';

// Fields copied from liveSessions to the public projection. Never `players`.
const PUBLIC_FIELDS = [
  'templateId', 'groupId', 'title', 'eventDate', 'eventEndDate', 'status',
  'playerCount', 'maxPlayers', 'costPerPlayer', 'isPrivate', 'sport',
  'minAge', 'maxAge', 'desiredGender', 'locationLat', 'locationLng',
  'locationAddress', 'district', 'format', 'g', 'l',
] as const;

/** Returns the public projection of a live session, or null if it is private. */
export function buildPublicEvent(
  id: string,
  data: Record<string, any>,
  groupName?: string,
): Record<string, any> | null {
  if (data.isPrivate !== false) return null;
  const out: Record<string, any> = {id};
  for (const f of PUBLIC_FIELDS) {
    if (data[f] !== undefined) out[f] = data[f];
  }
  if (groupName !== undefined) out.groupName = groupName;
  return out;
}

// Trigger region must match the Firestore database location.
export const mirrorPublicEvent = onDocumentWritten(
  {document: 'liveSessions/{id}', region: 'southamerica-east1'},
  async (event) => {
    const db = getFirestore();
    const id = event.params.id;
    const target = db.doc(`publicEvents/${id}`);
    const after = event.data?.after;
    if (!after?.exists) {
      await target.delete();
      return;
    }
    const data = after.data()!;
    if (data.isPrivate !== false) {
      await target.delete();
      return;
    }
    let groupName: string | undefined;
    if (data.groupId) {
      const g = await db.doc(`groups/${data.groupId}`).get();
      groupName = g.data()?.name;
    }
    const projection = buildPublicEvent(id, data, groupName);
    if (projection) await target.set(projection);
  },
);
