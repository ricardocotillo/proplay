import {setGlobalOptions} from 'firebase-functions/v2';
import {initializeApp} from 'firebase-admin/app';

initializeApp();
setGlobalOptions({region: 'southamerica-east1', maxInstances: 10});

export {cancelParticipation} from './cancelParticipation';
export {mirrorPublicEvent} from './publicEvents';
